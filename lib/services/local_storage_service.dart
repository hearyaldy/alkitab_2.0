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

      // Open core boxes
      await Hive.openBox(AppConstants.settingsBoxName);
      await Hive.openBox(AppConstants.bibleContentBoxName);
      await Hive.openBox(AppConstants.userBoxName);
      await Hive.openBox('devotionals');
      await Hive.openBox('sync_queue');

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

  /// Save data to a box - New method name
  static Future<void> saveData(
      String boxName, String key, dynamic value) async {
    try {
      final box = Hive.box(boxName);
      await box.put(key, value);
    } catch (e) {
      debugPrint('LocalStorageService: Error saving data - $e');
    }
  }

  /// Save data to a box - Compatible with existing auth_service
  static Future<void> saveValue(
      String boxName, String key, dynamic value) async {
    return saveData(boxName, key, value);
  }

  /// Get data from a box - New method name
  static dynamic getData(String boxName, String key, {dynamic defaultValue}) {
    try {
      final box = Hive.box(boxName);
      return box.get(key, defaultValue: defaultValue);
    } catch (e) {
      debugPrint('LocalStorageService: Error getting data - $e');
      return defaultValue;
    }
  }

  /// Get data from a box - Compatible with existing auth_service
  static dynamic getValue(String boxName, String key, {dynamic defaultValue}) {
    return getData(boxName, key, defaultValue: defaultValue);
  }

  /// Delete data from a box - New method name
  static Future<void> deleteData(String boxName, String key) async {
    try {
      final box = Hive.box(boxName);
      await box.delete(key);
    } catch (e) {
      debugPrint('LocalStorageService: Error deleting data - $e');
    }
  }

  /// Delete data from a box - Compatible with existing auth_service
  static Future<void> deleteValue(String boxName, String key) async {
    return deleteData(boxName, key);
  }

  /// Clear all data in a box
  static Future<void> clearBox(String boxName) async {
    try {
      final box = Hive.box(boxName);
      await box.clear();
    } catch (e) {
      debugPrint('LocalStorageService: Error clearing box - $e');
    }
  }

  /// Save a list of items
  static Future<void> saveList(String boxName, List<dynamic> items) async {
    try {
      final box = Hive.box(boxName);
      await box.clear(); // Clear existing items

      // Add each item with auto-incrementing key
      for (var item in items) {
        await box.add(item);
      }
    } catch (e) {
      debugPrint('LocalStorageService: Error saving list - $e');
    }
  }

  /// Get all items from a box as a list
  static List<dynamic> getList(String boxName) {
    try {
      final box = Hive.box(boxName);
      return box.values.toList();
    } catch (e) {
      debugPrint('LocalStorageService: Error getting list - $e');
      return [];
    }
  }

  /// Save timestamps for data tracking
  static Future<void> saveLastUpdatedTime(String dataType) async {
    try {
      final box = Hive.box(AppConstants.settingsBoxName);
      final now = DateTime.now().toIso8601String();
      await box.put('last_updated_$dataType', now);
    } catch (e) {
      debugPrint('LocalStorageService: Error saving timestamp - $e');
    }
  }

  /// Get the last updated time for a data type
  static DateTime? getLastUpdatedTime(String dataType) {
    try {
      final box = Hive.box(AppConstants.settingsBoxName);
      final timeString = box.get('last_updated_$dataType');
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
      return null;
    } catch (e) {
      debugPrint('LocalStorageService: Error getting timestamp - $e');
      return null;
    }
  }

  /// Check if data needs to be refreshed (older than the specified duration)
  static bool needsRefresh(String dataType,
      {Duration threshold = const Duration(hours: 24)}) {
    final lastUpdated = getLastUpdatedTime(dataType);
    if (lastUpdated == null) return true;

    final now = DateTime.now();
    return now.difference(lastUpdated) > threshold;
  }
}
