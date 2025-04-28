// lib/services/hive_migration_service.dart

import 'package:hive_flutter/hive_flutter.dart';

class HiveMigrationService {
  static Future<void> migrate() async {
    await _migrateBibleContentBox();
    // Add other migration functions here
  }

  static Future<void> _migrateBibleContentBox() async {
    if (!Hive.isBoxOpen('bible_content')) {
      await Hive.openBox('bible_content');
    }
    final box = Hive.box('bible_content');

    for (var key in box.keys) {
      final item = box.get(key);

      if (item is Map<String, dynamic>) {
        // Example: Add missing 'lastAccessed' field
        if (!item.containsKey('lastAccessed')) {
          item['lastAccessed'] = DateTime.now().toIso8601String();
          await box.put(key, item);
        }
      }
    }
  }
}
