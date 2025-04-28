// lib/services/local_storage_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';

class LocalStorageService {
  static bool _isInitialized = false;
  static final List<String> _boxNames = [
    AppConstants.settingsBoxName,
    AppConstants.bibleContentBoxName,
    AppConstants.userBoxName,
    'devotionals',
    'sync_queue',
    'offline_changes',
    'bookmarks',
    'highlights',
    'notes',
    'reading_history',
  ];

  /// Initialize Hive and open all required boxes
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);

      // Open all required boxes in parallel
      await Future.wait(
        _boxNames.map((name) => Hive.openBox(name)),
      );

      _isInitialized = true;
      debugPrint(
          'LocalStorageService: Initialized successfully with ${_boxNames.length} boxes');
    } catch (e) {
      debugPrint('LocalStorageService: Error initializing - $e');
      rethrow; // Let higher layer catch errors
    }
  }

  static Box<dynamic> _getBox(String boxName) {
    if (!_isInitialized) {
      throw Exception('LocalStorageService is not initialized!');
    }
    return Hive.box(boxName);
  }

  static Future<void> addToSyncQueue(
      String type, Map<String, dynamic> data) async {
    final box = _getBox('sync_queue');
    await box.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('Added to sync queue: $type');
  }

  static Future<List<dynamic>> getSyncQueue() async {
    final box = _getBox('sync_queue');
    return box.values.toList();
  }

  static Future<void> clearSyncQueueItems(List<dynamic> processedItems) async {
    final box = _getBox('sync_queue');
    for (var item in processedItems) {
      await box.delete(item.key);
    }
    debugPrint('Cleared ${processedItems.length} sync queue items');
  }

  static Future<void> storeOfflineChange({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final box = _getBox('offline_changes');
    await box.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('Stored offline change: $type');
  }

  static Future<List<dynamic>> getOfflineChanges() async {
    final box = _getBox('offline_changes');
    return box.values.toList();
  }

  static Future<void> clearOfflineChanges(
      List<dynamic> processedChanges) async {
    final box = _getBox('offline_changes');
    for (var change in processedChanges) {
      await box.delete(change.key);
    }
    debugPrint('Cleared ${processedChanges.length} offline changes');
  }
}
