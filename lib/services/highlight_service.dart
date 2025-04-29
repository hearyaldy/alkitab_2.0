// lib/services/highlight_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../models/highlight_model.dart';
import '../services/sync_queue_processor.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_manager.dart';
import '../utils/sync_conflict_resolver.dart';
import 'package:collection/collection.dart';

class HighlightService {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();
  final Uuid _uuid = const Uuid();

  static const String _highlightsBoxName = 'highlights';

  HighlightService(this._syncQueueProcessor);

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get all user highlights
  Future<List<HighlightModel>> getUserHighlights() async {
    final localHighlights = await _getLocalHighlights();

    if (_connectivityService.isOnline) {
      try {
        final serverHighlights = await _getServerHighlights();
        final merged = _mergeHighlights(localHighlights, serverHighlights);
        await _saveHighlightsToLocal(merged);
        await processHighlightSyncQueue();
        return merged;
      } catch (e) {
        return localHighlights;
      }
    }
    return localHighlights;
  }

  /// Get highlights for a specific chapter
  Future<List<HighlightModel>> getHighlightsForChapter({
    required String bookId,
    required int chapterId,
  }) async {
    final highlights = await getUserHighlights();
    return highlights
        .where((h) => h.bookId == bookId && h.chapterId == chapterId)
        .toList();
  }

  /// Get highlight color for a specific verse
  Future<String?> getHighlightColorForVerse({
    required String bookId,
    required int chapterId,
    required int verseId,
  }) async {
    final highlights = await getUserHighlights();
    final highlight = highlights.firstWhere(
      (h) =>
          h.bookId == bookId &&
          h.chapterId == chapterId &&
          h.verseId == verseId,
    );
    return highlight?.colorCode;
  }

  /// Add a highlight
  Future<void> addHighlight({
    required String bookId,
    required int chapterId,
    required int verseId,
    required String colorCode,
    String? verseText,
  }) async {
    final user = _supabase.auth.currentUser;
    final highlightId = _uuid.v4();
    final now = DateTime.now();

    final highlight = HighlightModel(
      id: highlightId,
      userId: user?.id ?? 'offline_user',
      bookId: bookId,
      chapterId: chapterId,
      verseId: verseId,
      colorCode: colorCode,
      createdAt: now,
      isSynced: false,
      verseText: verseText,
    );

    await _saveHighlightLocally(highlight);

    if (_connectivityService.isOnline && user != null) {
      try {
        final data = highlight.toJson();
        data.remove('is_synced');

        final response = await _supabase
            .from('user_highlights')
            .upsert(data)
            .select()
            .single();

        await _updateHighlightLocally(
          highlight.copyWith(
            isSynced: true,
          ),
        );
      } catch (e) {
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.highlight,
          data: highlight.toJson()..['operation'] = 'add',
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.highlight,
        data: highlight.toJson()..['operation'] = 'add',
      );
    }
  }

  /// Update a highlight
  Future<void> updateHighlight({
    required String id,
    required String colorCode,
  }) async {
    final highlights = await _getLocalHighlights();
    final highlight = highlights.firstWhere((h) => h.id == id,
        orElse: () => throw Exception('Highlight not found'));

    final updatedHighlight = highlight.copyWith(
      colorCode: colorCode,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    await _updateHighlightLocally(updatedHighlight);

    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) return;

        final data = updatedHighlight.toJson();
        data.remove('is_synced');

        await _supabase
            .from('user_highlights')
            .update(data)
            .eq('id', id)
            .eq('user_id', user.id);

        await _updateHighlightLocally(
            updatedHighlight.copyWith(isSynced: true));
      } catch (e) {
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.highlight,
          data: updatedHighlight.toJson()..['operation'] = 'update',
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.highlight,
        data: updatedHighlight.toJson()..['operation'] = 'update',
      );
    }
  }

  /// Delete a highlight
  Future<void> deleteHighlight(String id) async {
    if (!Hive.isBoxOpen(_highlightsBoxName)) {
      await Hive.openBox(_highlightsBoxName);
    }
    final box = Hive.box(_highlightsBoxName);
    await box.delete(id);

    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) return;

        await _supabase
            .from('user_highlights')
            .delete()
            .eq('id', id)
            .eq('user_id', user.id);
      } catch (e) {
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.highlight,
          data: {'id': id, 'operation': 'delete'},
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.highlight,
        data: {'id': id, 'operation': 'delete'},
      );
    }
  }

  /// Process highlight sync queue
  Future<void> processHighlightSyncQueue() async {
    if (_connectivityService.isOnline) {
      await _syncQueueProcessor.processQueue();
      await _offlineManager.updateContentTimestamp('highlights');
    }
  }

  Future<List<HighlightModel>> _getLocalHighlights() async {
    if (!Hive.isBoxOpen(_highlightsBoxName)) {
      await Hive.openBox(_highlightsBoxName);
    }
    final box = Hive.box(_highlightsBoxName);
    return box.values.map((e) {
      if (e is HighlightModel) return e;
      return HighlightModel.fromJson(jsonDecode(e));
    }).toList();
  }

  Future<List<HighlightModel>> _getServerHighlights() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response =
        await _supabase.from('user_highlights').select().eq('user_id', user.id);

    return (response as List)
        .map((json) => HighlightModel.fromJson(json))
        .toList();
  }

  Future<void> _saveHighlightLocally(HighlightModel highlight) async {
    if (!Hive.isBoxOpen(_highlightsBoxName)) {
      await Hive.openBox(_highlightsBoxName);
    }
    final box = Hive.box(_highlightsBoxName);
    await box.put(highlight.id, jsonEncode(highlight.toJson()));
  }

  Future<void> _updateHighlightLocally(HighlightModel highlight) async {
    await _saveHighlightLocally(highlight);
  }

  Future<void> _saveHighlightsToLocal(List<HighlightModel> highlights) async {
    if (!Hive.isBoxOpen(_highlightsBoxName)) {
      await Hive.openBox(_highlightsBoxName);
    }
    final box = Hive.box(_highlightsBoxName);
    await box.clear();
    for (var h in highlights) {
      await box.put(h.id, jsonEncode(h.toJson()));
    }
  }

  List<HighlightModel> _mergeHighlights(
    List<HighlightModel> local,
    List<HighlightModel> server,
  ) {
    final Map<String, HighlightModel> merged = {for (var h in server) h.id: h};

    for (var localHighlight in local) {
      if (!merged.containsKey(localHighlight.id)) {
        merged[localHighlight.id] = localHighlight;
      }
    }
    return merged.values.toList();
  }
}
