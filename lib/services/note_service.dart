// lib/services/note_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/note_model.dart';
import '../services/sync_queue_processor.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_service.dart';
import '../utils/offline_manager.dart';
import '../utils/sync_conflict_resolver.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NoteService {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();
  final Uuid _uuid = const Uuid();
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _notesBoxName = 'notes';

  NoteService(this._syncQueueProcessor);

  Future<List<NoteModel>> getUserNotes({String? type}) async {
    final localNotes = await _getLocalNotes(type: type);

    if (_connectivityService.isOnline) {
      try {
        final serverNotes = await _getServerNotes(type: type);
        final mergedNotes = _mergeNotes(localNotes, serverNotes);
        await _saveNotesToLocalStorage(mergedNotes);
        await processNoteSyncQueue();
        return mergedNotes;
      } catch (e) {
        debugPrint('Server notes fetch error: $e');
        return localNotes;
      }
    }
    return localNotes;
  }

  Future<List<NoteModel>> _getLocalNotes({String? type}) async {
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      final List<NoteModel> notes = [];

      for (var key in box.keys) {
        final jsonString = box.get(key);
        if (jsonString != null) {
          try {
            final note = NoteModel.fromJson(
              jsonString is String ? jsonDecode(jsonString) : jsonString,
            );
            if (type == null || note.noteType == type) {
              notes.add(note);
            }
          } catch (e) {
            debugPrint('Error parsing note from local: $e');
          }
        }
      }
      return notes;
    } catch (e) {
      debugPrint('Local notes fetch error: $e');
      return [];
    }
  }

  Future<List<NoteModel>> _getServerNotes({String? type}) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return [];

      Query query = _firestore.collection('user_notes').where('user_id', isEqualTo: user.uid);
      if (type != null) {
        query = query.where('note_type', isEqualTo: type);
      }

      final response = await query.get();
      final notes = response.docs
          .map<NoteModel>((doc) => NoteModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
      await _offlineManager.updateContentTimestamp('notes');

      return notes;
    } catch (e) {
      debugPrint('Server notes fetch error: $e');
      rethrow;
    }
  }

  Future<void> _saveNotesToLocalStorage(List<NoteModel> notes) async {
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      await box.clear();
      for (var note in notes) {
        await box.put(note.id, jsonEncode(note.toJson()));
      }
    } catch (e) {
      debugPrint('Error saving notes to local storage: $e');
    }
  }

  Future<NoteModel?> addNote({
    String? bookId,
    int? chapterId,
    int? verseId,
    required String content,
    String? devotionalId,
    String noteType = 'general',
    String? title,
  }) async {
    final user = _firebaseService.currentUser;
    final userId = user?.uid ?? 'offline_user';
    final noteId = _uuid.v4();
    final now = DateTime.now();

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

    final note = NoteModel.fromJson(noteData);

    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      await box.put(noteId, jsonEncode(noteData));
    } catch (e) {
      debugPrint('Error saving note locally: $e');
      return null;
    }

    if (_connectivityService.isOnline && user != null) {
      try {
        await _firestore.collection('user_notes').doc(noteId).set(noteData);

        if (!Hive.isBoxOpen(_notesBoxName)) {
          await Hive.openBox(_notesBoxName);
        }
        final box = Hive.box(_notesBoxName);
        final updatedData = {...noteData, 'is_synced': true};
        await box.put(noteId, jsonEncode(updatedData));

        return NoteModel.fromJson(updatedData);
      } catch (e) {
        debugPrint('Server note add error: $e');
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.note,
          data: {...noteData, 'operation': 'add'},
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.note,
        data: {...noteData, 'operation': 'add'},
      );
    }
    return note;
  }

  Future<bool> deleteNote(String noteId) async {
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      await box.delete(noteId);
    } catch (e) {
      debugPrint('Error deleting note locally: $e');
      return false;
    }

    if (_connectivityService.isOnline) {
      try {
        final user = _firebaseService.currentUser;
        if (user == null) {
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.note,
            data: {'id': noteId, 'operation': 'delete'},
          );
          return true;
        }

        await _firestore
            .collection('user_notes')
            .doc(noteId)
            .delete();

        return true;
      } catch (e) {
        debugPrint('Server note delete error: $e');
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.note,
          data: {'id': noteId, 'operation': 'delete'},
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.note,
        data: {'id': noteId, 'operation': 'delete'},
      );
    }
    return true;
  }

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
    NoteModel? existingNote;
    Map<String, dynamic>? existingData;

    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      final rawData = box.get(id);
      if (rawData != null) {
        existingNote = NoteModel.fromJson(
          rawData is String ? jsonDecode(rawData) : rawData,
        );
        existingData = rawData is String ? jsonDecode(rawData) : rawData;
      }
    } catch (e) {
      debugPrint('Error fetching local note: $e');
    }

    if (existingNote == null && existingData == null) {
      debugPrint('Note not found: $id');
      return null;
    }

    final updateData = {
      ...existingData ?? {},
      'id': id,
      'is_synced': false,
      'last_modified': DateTime.now().toIso8601String(),
    };

    if (bookId != null) updateData['book_id'] = bookId;
    if (chapterId != null) updateData['chapter_id'] = chapterId;
    if (verseId != null) updateData['verse_id'] = verseId;
    if (content != null) updateData['content'] = content;
    if (devotionalId != null) updateData['devotional_id'] = devotionalId;
    if (noteType != null) updateData['note_type'] = noteType;
    if (title != null) updateData['title'] = title;

    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      await box.put(id, jsonEncode(updateData));
    } catch (e) {
      debugPrint('Error updating note locally: $e');
      return null;
    }

    if (_connectivityService.isOnline) {
      try {
        final user = _firebaseService.currentUser;
        if (user == null) {
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.note,
            data: {...updateData, 'operation': 'update'},
          );
          return NoteModel.fromJson(updateData);
        }

        await _firestore
            .collection('user_notes')
            .doc(id)
            .update(updateData);

        if (!Hive.isBoxOpen(_notesBoxName)) {
          await Hive.openBox(_notesBoxName);
        }
        final box = Hive.box(_notesBoxName);
        final finalUpdatedData = {...updateData, 'is_synced': true};
        await box.put(id, jsonEncode(finalUpdatedData));

        return NoteModel.fromJson(finalUpdatedData);
      } catch (e) {
        debugPrint('Server note update error: $e');
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.note,
          data: {...updateData, 'operation': 'update'},
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.note,
        data: {...updateData, 'operation': 'update'},
      );
    }
    return NoteModel.fromJson(updateData);
  }

  Future<NoteModel?> getNoteById(String noteId) async {
    try {
      if (!Hive.isBoxOpen(_notesBoxName)) {
        await Hive.openBox(_notesBoxName);
      }
      final box = Hive.box(_notesBoxName);
      final data = box.get(noteId);

      if (data != null) {
        return NoteModel.fromJson(data is String ? jsonDecode(data) : data);
      }
    } catch (e) {
      debugPrint('Error fetching note by ID locally: $e');
    }

    if (_connectivityService.isOnline) {
      try {
        final user = _firebaseService.currentUser;
        if (user == null) return null;

        final doc = await _firestore
            .collection('user_notes')
            .doc(noteId)
            .get();

        if (!doc.exists) return null;

        final response = {...doc.data()! as Map<String, dynamic>, 'id': doc.id};

        if (!Hive.isBoxOpen(_notesBoxName)) {
          await Hive.openBox(_notesBoxName);
        }
        final box = Hive.box(_notesBoxName);
        await box.put(noteId, jsonEncode(response));

        return NoteModel.fromJson(response);
      } catch (e) {
        debugPrint('Server fetch error: $e');
      }
    }
    return null;
  }

  Future<List<NoteModel>> getNotesByType(String type) async {
    return getUserNotes(type: type);
  }

  Future<List<NoteModel>> getBibleNotes({
    required String bookId,
    required int chapterId,
    int? verseId,
  }) async {
    final notes = await getUserNotes(type: 'bible');
    return notes.where((note) {
      if (note.bookId != bookId || note.chapterId != chapterId) {
        return false;
      }
      if (verseId != null && note.verseId != verseId) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<List<NoteModel>> getDevotionalNotes({String? devotionalId}) async {
    final notes = await getUserNotes(type: 'devotional');
    if (devotionalId != null) {
      return notes.where((note) => note.devotionalId == devotionalId).toList();
    }
    return notes;
  }

  Future<void> processNoteSyncQueue() async {
    if (!_connectivityService.isOnline) return;
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;
      await _syncQueueProcessor.processQueue();
      await _offlineManager.updateContentTimestamp('notes');
    } catch (e) {
      debugPrint('Note sync processing error: $e');
    }
  }

  List<NoteModel> _mergeNotes(
      List<NoteModel> localNotes, List<NoteModel> serverNotes) {
    final Map<String, NoteModel> mergedMap = {};
    for (var note in serverNotes) {
      mergedMap[note.id] = note;
    }
    for (var localNote in localNotes) {
      final id = localNote.id;
      if (mergedMap.containsKey(id)) {
        final serverNote = mergedMap[id]!;
        if (localNote.isSynced ?? false) continue;
        final resolved = SyncConflictResolver.resolveConflict(
          localData: localNote.toJson(),
          cloudData: serverNote.toJson(),
          dataType: 'notes',
        );
        mergedMap[id] = NoteModel.fromJson(resolved);
      } else {
        mergedMap[id] = localNote;
      }
    }
    return mergedMap.values.toList();
  }

  Future<bool> shouldRefreshNotes() async {
    return _offlineManager.shouldRefreshContent('notes');
  }

  Future<List<NoteModel>> forceRefreshNotes() async {
    if (!_connectivityService.isOnline) {
      return _getLocalNotes();
    }
    try {
      final serverNotes = await _getServerNotes();
      final localNotes = await _getLocalNotes();
      final mergedNotes = _mergeNotes(localNotes, serverNotes);
      await _saveNotesToLocalStorage(mergedNotes);
      return mergedNotes;
    } catch (e) {
      debugPrint('Error refreshing notes: $e');
      return _getLocalNotes();
    }
  }
}
