// lib/services/sync_queue_processor.dart

import 'package:flutter/foundation.dart'; // ✅ for debugPrint
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';

enum SyncOperationType {
  bookmark,
  settings,
}

class SyncQueueProcessor {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> processQueue() async {
    final syncQueueBox = await Hive.openBox('sync_queue');
    final syncItems = syncQueueBox.toMap().entries.toList();

    for (var entry in syncItems) {
      final key = entry.key;
      final item = entry.value;

      try {
        if (item is Map<String, dynamic>) {
          final type = item['type'];
          final data = item['data'];

          if (type == SyncOperationType.bookmark.name) {
            await _processBookmarkSync(data);
          } else if (type == SyncOperationType.settings.name) {
            await _processSettingsSync(data);
          }

          await syncQueueBox.delete(key);
        }
      } catch (e) {
        debugPrint('Error processing sync queue item: $e');
      }
    }
  }

  Future<void> _processBookmarkSync(Map<String, dynamic> bookmarkData) async {
    try {
      await _supabase.from('user_bookmarks').upsert(bookmarkData);
    } catch (e) {
      debugPrint('Bookmark sync error during processing: $e');
    }
  }

  Future<void> _processSettingsSync(Map<String, dynamic> settingsData) async {
    try {
      await _supabase.from('user_settings').upsert(settingsData);
    } catch (e) {
      debugPrint('Settings sync error during processing: $e');
    }
  }

  Future<void> addToQueue({
    required SyncOperationType type,
    required Map<String, dynamic> data,
  }) async {
    final syncQueueBox = await Hive.openBox('sync_queue');
    await syncQueueBox.add({
      'type': type.name,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
