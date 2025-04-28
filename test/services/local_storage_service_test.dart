// test/services/local_storage_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alkitab_2_0/services/local_storage_service.dart'; // <-- adjust path if needed

void main() {
  setUp(() async {
    await Hive.initFlutter();
  });

  tearDown(() async {
    await Hive.close();
  });

  test('LocalStorageService initializes and opens required boxes', () async {
    await LocalStorageService.initialize();

    expect(Hive.isBoxOpen('settings'), isTrue);
    expect(Hive.isBoxOpen('bible_content'), isTrue);
    expect(Hive.isBoxOpen('user'), isTrue);
    expect(Hive.isBoxOpen('devotionals'), isTrue);
    expect(Hive.isBoxOpen('sync_queue'), isTrue);
    expect(Hive.isBoxOpen('offline_changes'), isTrue);
    expect(Hive.isBoxOpen('bookmarks'), isTrue);
    expect(Hive.isBoxOpen('highlights'), isTrue);
    expect(Hive.isBoxOpen('notes'), isTrue);
    expect(Hive.isBoxOpen('reading_history'), isTrue);
  });
}
