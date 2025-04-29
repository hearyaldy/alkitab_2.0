// lib/services/highlight_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/highlight_model.dart';
import '../services/sync_queue_processor.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_manager.dart';
import '../utils/sync_conflict_resolver.dart';
import '../config/constants.dart';

class HighlightService {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();
  final Uuid _uuid = const Uuid();

  // Box name for local storage
  static const String _highlightsBoxName = 'highlights';

  HighlightService(this._syncQueueProcessor);

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get user highlights with offline-first approach
  Future<List<HighlightModel>> getUserHighlights() async {
    // First try to get highlights from local storage
    final localHighlights = await _getLocalHighlights();

    // If online, also fetch from server and merge
    if (_connectivityService.isOnline) {
      try {
        final serverHighlights = await _getServerHighlights();

        // Merge local and server highlights with conflict resolution
        final mergedHighlights =
            _mergeHighlights(localHighlights, serverHighlights);

        // Update local cache with merged highlights
        await _saveHighlightsToLocalStorage(mergedHighlights);

        // Process any pending sync queue items
        await processHighlightSyncQueue();

        return mergedHighlights;
      } catch (e) {
        debugPrint('Server highlights fetch error: $e');
        // If server fetch fails, return local highlights
        return localHighlights;
      }
    }

    return localHighlights;
  }

  /// Get highlights from local storage
  Future<List<HighlightModel>> _getLocalHighlights() async {
    try {
      if (!Hive.isBoxOpen(_highlightsBoxName)) {
        await Hive.openBox(_highlightsBoxName);
      }

      final box = Hive.box(_highlightsBoxName);
      final List<HighlightModel> highlights = [];

      // Convert all stored highlights to HighlightModel objects
      for (var key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            final highlight = HighlightModel.fromJson(
              json is String ? jsonDecode(json) : json,
            );
            highlights.add(highlight);
          } catch (e) {
            debugPrint('Error parsing highlight from local storage: $e');
          }
        }
      }

      return highlights;
    } catch (e) {
      debugPrint('Local highlights fetch error: $e');
      return [];
    }
  }

  /// Get highlights from server
  Future<List<HighlightModel>> _getServerHighlights() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_highlights')
          .select()
          .eq('user_id', user.id);

      final highlights = response
          .map<HighlightModel>((json) => HighlightModel.fromJson(json))
          .toList();

      // Update timestamp for highlight content
      await _offlineManager.updateContentTimestamp('highlights');

      return highlights;
    } catch (e) {
      debugPrint('Server highlights fetch error: $e');
      throw e; // Re-throw to handle in calling method
    }
  }

  /// Save highlights to local storage
  Future<void> _saveHighlightsToLocalStorage(
      List<HighlightModel> highlights) async {
    try {
      if (!Hive.isBoxOpen(_highlightsBoxName)) {
        await Hive.openBox(_highlightsBoxName);
      }

      final box = Hive.box(_highlightsBoxName);

      // Clear existing highlights and save new ones
      await box.clear();

      for (var highlight in highlights) {
        await box.put(highlight.id, highlight.toJson());
      }
    } catch (e) {
      debugPrint('Error saving highlights to local storage: $e');
    }
  }

  /// Add a highlight with offline support
  Future<HighlightModel?> addHighlight({
    required String bookId,
    required int chapterId,
    required int verseId,
    required String colorCode,
    String? verseText,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'offline_user';

    // Generate a unique ID for the highlight
    final highlightId = _uuid.v4();

    // Create highlight data
    final highlightData = {
      'id': highlightId,
      'user_id': userId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'verse_id': verseId,
      'color_code': colorCode,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': false,
      'verse_text': verseText,
      'operation': 'add',
    };

    // Create highlight model
    final highlight = HighlightModel.fromJson(highlightData);

    // Save to local storage first
    try {
      if (!Hive.isBoxOpen(_highlightsBoxName)) {
        await Hive.openBox(_highlightsBoxName);
      }

      final box = Hive.box(_highlightsBoxName);
      await box.put(highlightId, highlightData);
    } catch (e) {
      debugPrint('Error saving highlight to local storage: $e');
      return null;
    }

    // If online, try to sync with server
    if (_connectivityService.isOnline && user != null) {
      try {
        final dataToUpsert = Map<String, dynamic>.from(highlightData);
        dataToUpsert.remove('operation');

        final response = await _supabase
            .from('user_highlights')
            .upsert(dataToUpsert)
            .select()
            .single();

        // Update local storage with server response
        if (!Hive.isBoxOpen(_highlightsBoxName)) {
          await Hive.openBox(_highlightsBoxName);
        }

        final box = Hive.box(_highlightsBoxName);
        final updatedData = {...highlightData, ...response, 'is_synced': true};
        await box.put(highlightId, updatedData);

        return HighlightModel.fromJson(response);
      } catch (e) {
        debugPrint('Server highlight add error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.highlights,
          data: highlightData,
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.highlights,
        data: highlightData,
      );
    }

    return highlight;
  }

  /// Delete a highlight with offline support
  Future<bool> deleteHighlight(String highlightId) async {
    // Delete from local storage first
    try {
      if (!Hive.isBoxOpen(_highlightsBoxName)) {
        await Hive.openBox(_highlightsBoxName);
      }

      final box = Hive.box(_highlightsBoxName);
      await box.delete(highlightId);
    } catch (e) {
      debugPrint('Error deleting highlight from local storage: $e');
      return false;
    }

    // If online, try to delete from server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          // Add to sync queue for when user logs in
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.highlights,
            data: {
              'id': highlightId,
              'operation': 'delete',
            },
          );
          return true;
        }

        await _supabase
            .from('user_highlights')
            .delete()
            .eq('id', highlightId)
            .eq('user_id', user.id);

        return true;
      } catch (e) {
        debugPrint('Server highlight delete error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.highlights,
          data: {
            'id': highlightId,
            'operation': 'delete',
          },
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.highlights,
        data: {
          'id': highlightId,
          'operation': 'delete',
        },
      );
    }

    return true;
  }

  /// Update a highlight with offline support
  Future<HighlightModel?> updateHighlight({
    required String id,
    String? colorCode,
  }) async {
    // Get existing highlight from local storage
    HighlightModel? existingHighlight;
    Map<String, dynamic>? existingData;

    try {
      if (!Hive.isBoxOpen(_highlightsBoxName)) {
        await Hive.openBox(_highlightsBoxName);
      }

      final box = Hive.box(_highlightsBoxName);
      existingData = box.get(id);

      if (existingData != null) {
        existingHighlight = HighlightModel.fromJson(
          existingData is String ? jsonDecode(existingData) : existingData,
        );
      }
    } catch (e) {
      debugPrint('Error getting existing highlight: $e');
    }

    if (existingHighlight == null && existingData == null) {
      debugPrint('Highlight not found: $id');
      return null;
    }

    // Prepare update data
    final updateData = <String, dynamic>{
      ...existingData ?? {},
      'id': id,
      'is_synced': false,
      'operation': 'update',
    };

    if (colorCode != null) updateData['color_code'] = colorCode;

    // Update last_modified timestamp (if applicable)
    updateData['last_modified'] = DateTime.now().toIso8601String();

    // Update local storage
    try {
      if (!Hive.isBoxOpen(_highlightsBoxName)) {
        await Hive.openBox(_highlightsBoxName);
      }

      final box = Hive.box(_highlightsBoxName);
      await box.put(id, updateData);
    } catch (e) {
      debugPrint('Error updating highlight in local storage: $e');
      return null;
    }

    // If online, try to update on server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          // Add to sync queue for when user logs in
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.highlights,
            data: updateData,
          );
          return HighlightModel.fromJson(updateData);
        }

        final dataToUpsert = Map<String, dynamic>.from(updateData);
        dataToUpsert.remove('operation');

        final response = await _supabase
            .from('user_highlights')
            .update(dataToUpsert)
            .eq('id', id)
            .eq('user_id', user.id)
            .select()
            .single();

        // Update local storage with server response
        if (!Hive.isBoxOpen(_highlightsBoxName)) {
          await Hive.openBox(_highlightsBoxName);
        }

        final box = Hive.box(_highlightsBoxName);
        final updatedData = {...updateData, ...response, 'is_synced': true};
        await box.put(id, updatedData);

        return HighlightModel.fromJson(response);
      } catch (e) {
        debugPrint('Server highlight update error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.highlights,
          data: updateData,
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.highlights,
        data: updateData,
      );
    }

    return HighlightModel.fromJson(updateData);
  }

  /// Get highlights for a specific verse
  Future<List<HighlightModel>> getHighlightsForVerse({
    required String bookId,
    required int chapterId,
    required int verseId,
  }) async {
    final highlights = await getUserHighlights();

    return highlights
        .where((highlight) =>
            highlight.bookId == bookId &&
            highlight.chapterId == chapterId &&
            highlight.verseId == verseId)
        .toList();
  }

  /// Get highlights for a specific chapter
  Future<List<HighlightModel>> getHighlightsForChapter({
    required String bookId,
    required int chapterId,
  }) async {
    final highlights = await getUserHighlights();

    return highlights
        .where((highlight) =>
            highlight.bookId == bookId && highlight.chapterId == chapterId)
        .toList();
  }

  /// Process highlight sync queue
  Future<void> processHighlightSyncQueue() async {
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

      // Update timestamp for highlight content
      await _offlineManager.updateContentTimestamp('highlights');
    } catch (e) {
      debugPrint('Highlight sync queue processing error: $e');
    }
  }

  /// Merge local and server highlights with conflict resolution
  List<HighlightModel> _mergeHighlights(
    List<HighlightModel> localHighlights,
    List<HighlightModel> serverHighlights,
  ) {
    // Create a map of ID -> highlight for faster lookup
    final Map<String, HighlightModel> mergedMap = {};

    // First, add all server highlights to the map
    for (var highlight in serverHighlights) {
      mergedMap[highlight.id] = highlight;
    }

    // Then, handle local highlights
    for (var localHighlight in localHighlights) {
      final id = localHighlight.id;

      // If highlight exists in both local and server, resolve conflicts
      if (mergedMap.containsKey(id)) {
        final serverHighlight = mergedMap[id]!;

        // Only merge if local highlight is not synced
        if (localHighlight.isSynced == true) {
          // Local highlight is already synced, keep server version
          continue;
        }

        // Resolve conflict between local and server highlight
        final localData = localHighlight.toJson();
        final serverData = serverHighlight.toJson();

        final resolvedData = SyncConflictResolver.resolveConflict(
          localData: localData,
          cloudData: serverData,
          dataType: 'highlights',
        );

        mergedMap[id] = HighlightModel.fromJson(resolvedData);
      } else {
        // Highlight only exists locally, add it to the merged map
        mergedMap[id] = localHighlight;
      }
    }

    // Convert map back to list
    return mergedMap.values.toList();
  }

  /// Check if there is already a highlight for the verse
  Future<bool> hasHighlightForVerse({
    required String bookId,
    required int chapterId,
    required int verseId,
  }) async {
    final highlights = await getHighlightsForVerse(
      bookId: bookId,
      chapterId: chapterId,
      verseId: verseId,
    );

    return highlights.isNotEmpty;
  }

  /// Get the highlight color for a specific verse, or null if not highlighted
  Future<String?> getHighlightColorForVerse({
    required String bookId,
    required int chapterId,
    required int verseId,
  }) async {
    final highlights = await getHighlightsForVerse(
      bookId: bookId,
      chapterId: chapterId,
      verseId: verseId,
    );

    return highlights.isNotEmpty ? highlights.first.colorCode : null;
  }
}
