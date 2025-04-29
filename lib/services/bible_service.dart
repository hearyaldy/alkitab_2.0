// lib/services/bible_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:alkitab_2_0/models/bible_model.dart';

class BibleService {
  static const versionUrls = {
    'ABB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tm.json',
    'ATB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tb.json',
  };

  static Future<List<BibleBook>> fetchBooks(String versionCode) async {
    final localBooks = await _getBooksFromLocalStorage(versionCode);
    if (localBooks.isNotEmpty) return localBooks;

    try {
      final books = await _fetchBooksFromNetwork(versionCode);
      await _cacheBooksLocally(versionCode, books);
      return books;
    } catch (e) {
      debugPrint('Error fetching books: $e');
      return [];
    }
  }

  static Future<List<BibleBook>> _fetchBooksFromNetwork(
      String versionCode) async {
    final url = versionUrls[versionCode];
    if (url == null) throw Exception('Invalid Bible version: $versionCode');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200)
      throw Exception('Failed to load Bible data');

    final data = json.decode(response.body);
    final List<dynamic> verses = data['verses'];

    final Map<int, String> bookMap = {};
    for (var v in verses) {
      bookMap[v['book']] = v['book_name'];
    }

    return bookMap.entries.map((e) {
      final bookId = e.value.toLowerCase().replaceAll(' ', '_');
      return BibleBook(
        id: bookId,
        name: e.value,
        abbreviation: bookId.substring(0, 3),
        order: e.key,
        testament: e.key <= 39 ? 'OT' : 'NT',
        chapters: 1,
      );
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  static Future<void> _cacheBooksLocally(
      String versionCode, List<BibleBook> books) async {
    final box = await Hive.openBox('bible_books_$versionCode');
    await box.clear();
    for (var book in books) {
      await box.put(book.id, book.toJson());
    }
  }

  static Future<List<BibleBook>> _getBooksFromLocalStorage(
      String versionCode) async {
    final box = await Hive.openBox('bible_books_$versionCode');
    return box.values
        .map((bookJson) =>
            BibleBook.fromJson(Map<String, dynamic>.from(bookJson)))
        .toList();
  }

  static Future<List<BibleVerse>> fetchVerses({
    required String bookId,
    required int chapterId,
    String version = 'ABB',
  }) async {
    final localVerses = await _getVersesFromLocalStorage(
      bookId: bookId,
      chapterId: chapterId,
      version: version,
    );
    if (localVerses.isNotEmpty) return localVerses;

    try {
      final verses = await _fetchVersesFromNetwork(
        bookId: bookId,
        chapterId: chapterId,
        version: version,
      );

      await _cacheVersesLocally(
        bookId: bookId,
        chapterId: chapterId,
        version: version,
        verses: verses,
      );
      return verses;
    } catch (e) {
      debugPrint('Error fetching verses: $e');
      return [];
    }
  }

  static Future<List<BibleVerse>> _fetchVersesFromNetwork({
    required String bookId,
    required int chapterId,
    required String version,
  }) async {
    final url = versionUrls[version];
    if (url == null) throw Exception('Invalid Bible version: $version');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200)
      throw Exception('Failed to load Bible verses');

    final data = json.decode(response.body);
    final List<dynamic> allVerses = data['verses'];

    final bookNum = _getBookNumber(bookId);
    final filtered = allVerses
        .where((v) => v['book'] == bookNum && v['chapter'] == chapterId)
        .toList();

    return filtered
        .map((v) => BibleVerse(
              id: v['verse'],
              bookId: bookId,
              chapterId: chapterId,
              verseNumber: v['verse'],
              text: v['text'],
            ))
        .toList();
  }

  static Future<void> _cacheVersesLocally({
    required String bookId,
    required int chapterId,
    required String version,
    required List<BibleVerse> verses,
  }) async {
    final boxName = 'bible_verses_${version}_${bookId}_$chapterId';
    final box = await Hive.openBox(boxName);
    await box.clear();
    for (var verse in verses) {
      await box.put(verse.verseNumber, verse.toJson());
    }
  }

  static Future<List<BibleVerse>> _getVersesFromLocalStorage({
    required String bookId,
    required int chapterId,
    required String version,
  }) async {
    final boxName = 'bible_verses_${version}_${bookId}_$chapterId';
    final box = await Hive.openBox(boxName);
    return box.values
        .map((verseJson) =>
            BibleVerse.fromJson(Map<String, dynamic>.from(verseJson)))
        .toList();
  }

  static int _getBookNumber(String bookId) {
    const map = {
      'genesis': 1,
      'exodus': 2,
      'leviticus': 3,
      'numbers': 4,
      'deuteronomy': 5,
      'joshua': 6,
      'judges': 7,
      'ruth': 8,
      '1_samuel': 9,
      '2_samuel': 10,
      '1_kings': 11,
      '2_kings': 12,
      '1_chronicles': 13,
      '2_chronicles': 14,
      'ezra': 15,
      'nehemiah': 16,
      'esther': 17,
      'job': 18,
      'psalms': 19,
      'proverbs': 20,
      'ecclesiastes': 21,
      'song_of_solomon': 22,
      'isaiah': 23,
      'jeremiah': 24,
      'lamentations': 25,
      'ezekiel': 26,
      'daniel': 27,
      'hosea': 28,
      'joel': 29,
      'amos': 30,
      'obadiah': 31,
      'jonah': 32,
      'micah': 33,
      'nahum': 34,
      'habakkuk': 35,
      'zephaniah': 36,
      'haggai': 37,
      'zechariah': 38,
      'malachi': 39,
      'matthew': 40,
      'mark': 41,
      'luke': 42,
      'john': 43,
      'acts': 44,
      'romans': 45,
      '1_corinthians': 46,
      '2_corinthians': 47,
      'galatians': 48,
      'ephesians': 49,
      'philippians': 50,
      'colossians': 51,
      '1_thessalonians': 52,
      '2_thessalonians': 53,
      '1_timothy': 54,
      '2_timothy': 55,
      'titus': 56,
      'philemon': 57,
      'hebrews': 58,
      'james': 59,
      '1_peter': 60,
      '2_peter': 61,
      '1_john': 62,
      '2_john': 63,
      '3_john': 64,
      'jude': 65,
      'revelation': 66,
    };
    return map[bookId] ?? 1;
  }

  // Optional static helper inside class
  static Future<List<BibleVerse>> getBookVerses(
    String bookId,
    int chapterId, {
    String version = 'ABB',
  }) {
    return fetchVerses(bookId: bookId, chapterId: chapterId, version: version);
  }
}

// Legacy global alias outside class (optional)
Future<List<BibleVerse>> getBookVerses(String bookId, int chapterId,
    {String version = 'ABB'}) {
  return BibleService.fetchVerses(
      bookId: bookId, chapterId: chapterId, version: version);
}
