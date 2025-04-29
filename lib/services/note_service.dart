// lib/services/note_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/note_model.dart';
import '../services/sync_queue_processor.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_manager.dart';
import '../utils/sync_conflict_resolver.dart';
import '../config/constants.dart';

class NoteService {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();
  final Uuid _uuid = const Uuid();

  // Box name for local storage
  static const String _notesBoxName = 'notes';

  NoteService(this._syncQueueProcessor);

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get user notes with offline-first approach
  Future<List<NoteModel>> getUserNotes({String? type}) async {
    // First try to get notes from local storage
    final localNotes = await _getLocalNotes(type: type);

    // If online, also fetch from server and merge
    if (_connectivityService.isOnline) {
      try {
        final serverNotes = await _getServerNotes(type: type);

        // Merge local and server notes with conflict resolution
        final mergedNotes = _mergeNotes(localNotes, serverNotes);

        // Update local cache with merged notes
        await _saveNotesToLocalStorage(mergedNotes);

        // Process any pending sync queue items
        await processNoteSyncQueue();

        return mergedNotes;
      } catch (e) {
        debugPrint('Server notes fetch error: $e');
        // If server fetch fails, return local notes
        return localNotes;
      }
    }

    return localNotes;
  }

  /// Get notes from local storage
  Future<List<NoteModel>> _getLocalNotes({String? type}) async {
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);
      final List<NoteModel> notes = [];

      // Convert all stored notes to NoteModel objects
      for (var key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            final note = NoteModel.fromJson(
              json is String ? jsonDecode(json) : json,
            );

            // Filter by type if specified
            if (type == null || note.noteType == type) {
              notes.add(note);
            }
          } catch (e) {
            debugPrint('Error parsing note from local storage: $e');
          }
        }
      }

      return notes;
    } catch (e) {
      debugPrint('Local notes fetch error: $e');
      return [];
    }
  }

  /// Get notes from server
  Future<List<NoteModel>> _getServerNotes({String? type}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      var query = _supabase.from('user_notes').select().eq('user_id', user.id);
      if (type != null) {
        query = query.eq('note_type', type);
      }

      final response = await query;
      final notes =
          response.map<NoteModel>((json) => NoteModel.fromJson(json)).toList();

      // Update timestamp for note content
      await _offlineManager.updateContentTimestamp('notes');

      return notes;
    } catch (e) {
      debugPrint('Server notes fetch error: $e');
      throw e; // Re-throw to handle in calling method
    }
  }

  /// Save notes to local storage
  Future<void> _saveNotesToLocalStorage(List<NoteModel> notes) async {
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);

      // Clear existing notes and save new ones
      await box.clear();

      for (var note in notes) {
        await box.put(note.id, note.toJson());
      }
    } catch (e) {
      debugPrint('Error saving notes to local storage: $e');
    }
  }

  /// Add a note with offline support
  Future<NoteModel?> addNote({
    String? bookId,
    int? chapterId,
    int? verseId,
    required String content,
    String? devotionalId,
    String noteType = 'general',
    String? title,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'offline_user';

    // Generate a unique ID for the note
    final noteId = _uuid.v4();
    final now = DateTime.now();

    // Create note data
    final noteData = {
      'id': noteId,
      'user_id': userId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'verse_id': verseId,
      'content': content,
      'created_at': now.toIso8601String(),
      'last_modified': now.toIso8601String(),
      'is_synced': false,
      'devotional_id': devotionalId,
      'note_type': noteType,
      'title': title,
    };

    // Create note model
    final note = NoteModel.fromJson(noteData);

    // Save to local storage first
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);
      await box.put(noteId, noteData);
    } catch (e) {
      debugPrint('Error saving note to local storage: $e');
      return null;
    }

    // If online, try to sync with server
    if (_connectivityService.isOnline && user != null) {
      try {
        final response = await _supabase
            .from('user_notes')
            .upsert(noteData)
            .select()
            .single();

        // Update local storage with server response
        if (!Hive.isBoxOpen(_notesBoxName)) {
          await Hive.openBox(_notesBoxName);
        }

        final box = Hive.box(_notesBoxName);
        final updatedData = {...noteData, ...response, 'is_synced': true};
        await box.put(noteId, updatedData);

        return NoteModel.fromJson(response);
      } catch (e) {
        debugPrint('Server note add error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.notes,
          data: {
            ...noteData,
            'operation': 'add',
          },
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.notes,
        data: {
          ...noteData,
          'operation': 'add',
        },
      );
    }

    return note;
  }

  /// Delete a note with offline support
  Future<bool> deleteNote(String noteId) async {
    // Delete from local storage first
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);
      await box.delete(noteId);
    } catch (e) {
      debugPrint('Error deleting note from local storage: $e');
      return false;
    }

    // If online, try to delete from server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          // Add to sync queue for when user logs in
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.notes,
            data: {
              'id': noteId,
              'operation': 'delete',
            },
          );
          return true;
        }

        await _supabase
            .from('user_notes')
            .delete()
            .eq('id', noteId)
            .eq('user_id', user.id);

        return true;
      } catch (e) {
        debugPrint('Server note delete error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.notes,
          data: {
            'id': noteId,
            'operation': 'delete',
          },
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.notes,
        data: {
          'id': noteId,
          'operation': 'delete',
        },
      );
    }

    return true;
  }

  /// Update a note with offline support
  Future<NoteModel?> updateNote({
    required String id,
    String? bookId,
    int? chapterId,
    int? verseId,
    String? content,
    String? devotionalId,
    String? noteType,
    String? title,
  }) async {
    // Get existing note from local storage
    NoteModel? existingNote;
    Map<String, dynamic>? existingData;

    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);
      existingData = box.get(id);

      if (existingData != null) {
        existingNote = NoteModel.fromJson(
          existingData is String ? jsonDecode(existingData) : existingData,
        );
      }
    } catch (e) {
      debugPrint('Error getting existing note: $e');
    }

    if (existingNote == null && existingData == null) {
      debugPrint('Note not found: $id');
      return null;
    }

    // Prepare update data
    final updateData = <String, dynamic>{
      ...existingData ?? {},
      'id': id,
      'is_synced': false,
    };

    if (bookId != null) updateData['book_id'] = bookId;
    if (chapterId != null) updateData['chapter_id'] = chapterId;
    if (verseId != null) updateData['verse_id'] = verseId;
    if (content != null) updateData['content'] = content;
    if (devotionalId != null) updateData['devotional_id'] = devotionalId;
    if (noteType != null) updateData['note_type'] = noteType;
    if (title != null) updateData['title'] = title;

    // Update last_modified timestamp
    updateData['last_modified'] = DateTime.now().toIso8601String();

    // Update local storage
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);
      await box.put(id, updateData);
    } catch (e) {
      debugPrint('Error updating note in local storage: $e');
      return null;
    }

    // If online, try to update on server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          // Add to sync queue for when user logs in
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.notes,
            data: {
              ...updateData,
              'operation': 'update',
            },
          );
          return NoteModel.fromJson(updateData);
        }

        final response = await _supabase
            .from('user_notes')
            .update(updateData)
            .eq('id', id)
            .eq('user_id', user.id)
            .select()
            .single();

        // Update local storage with server response
        if (!Hive.isBoxOpen(_notesBoxName)) {
          await Hive.openBox(_notesBoxName);
        }

        final box = Hive.box(_notesBoxName);
        final updatedData = {...updateData, ...response, 'is_synced': true};
        await box.put(id, updatedData);

        return NoteModel.fromJson(response);
      } catch (e) {
        debugPrint('Server note update error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.notes,
          data: {
            ...updateData,
            'operation': 'update',
          },
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.notes,
        data: {
          ...updateData,
          'operation': 'update',
        },
      );
    }

    return NoteModel.fromJson(updateData);
  }

  /// Get note by ID with offline support
  Future<NoteModel?> getNoteById(String noteId) async {
    // First try to get from local storage
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }

      final box = Hive.box(_notesBoxName);
      final data = box.get(noteId);

      if (data != null) {
        return NoteModel.fromJson(
          data is String ? jsonDecode(data) : data,
        );
      }
    } catch (e) {
      debugPrint('Error getting note from local storage: $e');
    }

    // If not found locally and online, try server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) return null;

        final response = await _supabase
            .from('user_notes')
            .select()
            .eq('id', noteId)
            .eq('user_id', user.id)
            .single();

        // Save to local storage
        if (!Hive.isBoxOpen(_notesBoxName)) {
          await Hive.openBox(_notesBoxName);
        }

        final box = Hive.box(_notesBoxName);
        await box.put(noteId, response);

        return NoteModel.fromJson(response);
      } catch (e) {
        debugPrint('Server note fetch by ID error: $e');
        return null;
      }
    }

    return null;
  }

  /// Get notes by type with offline support
  Future<List<NoteModel>> getNotesByType(String type) async {
    return getUserNotes(type: type);
  }

  /// Get Bible notes for a specific verse
  Future<List<NoteModel>> getBibleNotes({
    required String bookId,
    required int chapterId,
    int? verseId,
  }) async {
    final notes = await getUserNotes(type: 'bible');

    return notes.where((note) {
      // Must match book and chapter
      if (note.bookId != bookId || note.chapterId != chapterId) {
        return false;
      }

      // If verseId is provided, match it as well
      if (verseId != null && note.verseId != verseId) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get devotional notes
  Future<List<NoteModel>> getDevotionalNotes({String? devotionalId}) async {
    final notes = await getUserNotes(type: 'devotional');

    if (devotionalId != null) {
      return notes.where((note) => note.devotionalId == devotionalId).toList();
    }

    return notes;
  }

  /// Process note sync queue
  Future<void> processNoteSyncQueue() async {
    if (!_connectivityService.isOnline) {
      debugPrint('Cannot process sync queue while offline');
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('Cannot process sync queue without logged in user');
        return;
      }

      final syncQueueProcessor = _syncQueueProcessor;
      await syncQueueProcessor.processQueue();

      // Update timestamp for note content
      await _offlineManager.updateContentTimestamp('notes');
    } catch (e) {
      debugPrint('Note sync queue processing error: $e');
    }
  }

  /// Merge local and server notes with conflict resolution
  List<NoteModel> _mergeNotes(
    List<NoteModel> localNotes,
    List<NoteModel> serverNotes,
  ) {
    // Create a map of ID -> note for faster lookup
    final Map<String, NoteModel> mergedMap = {};

    // First, add all server notes to the map
    for (var note in serverNotes) {
      mergedMap[note.id] = note;
    }

    // Then, handle local notes
    for (var localNote in localNotes) {
      final id = localNote.id;

      // If note exists in both local and server, resolve conflicts
      if (mergedMap.containsKey(id)) {
        final serverNote = mergedMap[id]!;

        // Only merge if local note is not synced
        if (localNote.isSynced ?? false) {
          // Local note is already synced, keep server version
          continue;
        }

        // Resolve conflict between local and server note
        final localData = localNote.toJson();
        final serverData = serverNote.toJson();

        final resolvedData = SyncConflictResolver.resolveConflict(
          localData: localData,
          cloudData: serverData,
          dataType: 'notes',
        );

        mergedMap[id] = NoteModel.fromJson(resolvedData);
      } else {
        // Note only exists locally, add it to the merged map
        mergedMap[id] = localNote;
      }
    }

    // Convert map back to list
    return mergedMap.values.toList();
  }

  /// Check if notes need to be refreshed
  Future<bool> shouldRefreshNotes() async {
    return _offlineManager.shouldRefreshContent('notes');
  }

  /// Force refresh notes from server
  Future<List<NoteModel>> forceRefreshNotes() async {
    if (!_connectivityService.isOnline) {
      return _getLocalNotes();
    }

    try {
      final serverNotes = await _getServerNotes();
      final localNotes = await _getLocalNotes();

      // Merge local and server notes
      final mergedNotes = _mergeNotes(localNotes, serverNotes);

      // Save merged notes to local storage
      await _saveNotesToLocalStorage(mergedNotes);

      return mergedNotes;
    } catch (e) {
      debugPrint('Error refreshing notes: $e');
      return _getLocalNotes();
    }
  }
}

// Add this to SyncOperationType enum in the sync_queue_processor.dart file
extension SyncOperationTypeExtension on SyncOperationType {
  static SyncOperationType notes = SyncOperationType.notes;
}
