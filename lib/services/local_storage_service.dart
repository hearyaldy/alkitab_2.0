// lib/services/local_storage_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';

class LocalStorageService {
  static bool _isInitialized = false;

  /// Initialize Hive and open all required boxes
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);

      // Existing box initializations
      await Hive.openBox(AppConstants.settingsBoxName);
      await Hive.openBox(AppConstants.bibleContentBoxName);
      await Hive.openBox(AppConstants.userBoxName);
      await Hive.openBox('devotionals');

      // New sync-related boxes
      await Hive.openBox('sync_queue');
      await Hive.openBox('offline_changes');

      // User data boxes
      await Hive.openBox('bookmarks');
      await Hive.openBox('highlights');
      await Hive.openBox('notes');
      await Hive.openBox('reading_history');

      _isInitialized = true;
      debugPrint('LocalStorageService: Initialized successfully');
    } catch (e) {
      debugPrint('LocalStorageService: Error initializing - $e');
    }
  }

  // Existing methods remain the same...

  /// New method to manage sync queue
  static Future<void> addToSyncQueue(
      String type, Map<String, dynamic> data) async {
    try {
      final box = await Hive.openBox('sync_queue');
      await box.add({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Added to sync queue: $type');
    } catch (e) {
      debugPrint('Error adding to sync queue: $e');
    }
  }

  /// Retrieve sync queue items
  static Future<List<dynamic>> getSyncQueue() async {
    try {
      final box = await Hive.openBox('sync_queue');
      return box.values.toList();
    } catch (e) {
      debugPrint('Error retrieving sync queue: $e');
      return [];
    }
  }

  /// Clear processed sync queue items
  static Future<void> clearSyncQueueItems(List<dynamic> processedItems) async {
    try {
      final box = await Hive.openBox('sync_queue');
      for (var item in processedItems) {
        await box.delete(item.key);
      }
      debugPrint('Cleared ${processedItems.length} sync queue items');
    } catch (e) {
      debugPrint('Error clearing sync queue: $e');
    }
  }

  /// Store offline changes
  static Future<void> storeOfflineChange(
      {required String type, required Map<String, dynamic> data}) async {
    try {
      final box = await Hive.openBox('offline_changes');
      await box.add({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Stored offline change: $type');
    } catch (e) {
      debugPrint('Error storing offline change: $e');
    }
  }

  /// Retrieve offline changes
  static Future<List<dynamic>> getOfflineChanges() async {
    try {
      final box = await Hive.openBox('offline_changes');
      return box.values.toList();
    } catch (e) {
      debugPrint('Error retrieving offline changes: $e');
      return [];
    }
  }

  /// Clear processed offline changes
  static Future<void> clearOfflineChanges(
      List<dynamic> processedChanges) async {
    try {
      final box = await Hive.openBox('offline_changes');
      for (var change in processedChanges) {
        await box.delete(change.key);
      }
      debugPrint('Cleared ${processedChanges.length} offline changes');
    } catch (e) {
      debugPrint('Error clearing offline changes: $e');
    }
  }
}
