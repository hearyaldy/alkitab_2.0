// test/services/local_storage_service_test.dart

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alkitab_2_0/config/constants.dart';
import 'package:alkitab_2_0/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('alkitab_hive_test');
    // path_provider has no platform implementation in unit tests,
    // so point it at a temporary directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return tempDir.path;
    });
  });

  tearDown(() async {
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await tempDir.delete(recursive: true);
  });

  test('LocalStorageService initializes and opens required boxes', () async {
    await LocalStorageService.initialize();

    expect(Hive.isBoxOpen(AppConstants.settingsBoxName), isTrue);
    expect(Hive.isBoxOpen(AppConstants.bibleContentBoxName), isTrue);
    expect(Hive.isBoxOpen(AppConstants.userBoxName), isTrue);
    expect(Hive.isBoxOpen('devotionals'), isTrue);
    expect(Hive.isBoxOpen('sync_queue'), isTrue);
    expect(Hive.isBoxOpen('offline_changes'), isTrue);
    expect(Hive.isBoxOpen('bookmarks'), isTrue);
    expect(Hive.isBoxOpen('highlights'), isTrue);
    expect(Hive.isBoxOpen('notes'), isTrue);
    expect(Hive.isBoxOpen('reading_history'), isTrue);
  });
}
