import 'package:hive_flutter/hive_flutter.dart';
import '../models/bible_model.dart';

class BibleContentCacheManager {
  static const String _boxPrefix = 'bible_content_';

  // Generate a unique box name for specific version, book, and chapter
  static String _getBoxName(String version, String bookId, int chapterId) {
    return '${_boxPrefix}${version}_${bookId}_$chapterId';
  }

  // Cache verses for a specific book and chapter
  static Future<void> cacheVerses({
    required String version,
    required String bookId,
    required int chapterId,
    required List<BibleVerse> verses,
  }) async {
    final boxName = _getBoxName(version, bookId, chapterId);
    final box = await Hive.openBox(boxName);

    // Clear existing data
    await box.clear();

    // Save verses
    for (var verse in verses) {
      await box.put(verse.verseNumber, verse.toJson());
    }
  }

  // Retrieve cached verses
  static Future<List<BibleVerse>> getCachedVerses({
    required String version,
    required String bookId,
    required int chapterId,
  }) async {
    final boxName = _getBoxName(version, bookId, chapterId);
    final box = await Hive.openBox(boxName);

    return box.values
        .map((verseJson) => BibleVerse.fromJson(verseJson))
        .toList();
  }

  // Check if verses are cached
  static Future<bool> isVersesCached({
    required String version,
    required String bookId,
    required int chapterId,
  }) async {
    final boxName = _getBoxName(version, bookId, chapterId);
    final box = await Hive.openBox(boxName);

    return box.isNotEmpty;
  }
}
