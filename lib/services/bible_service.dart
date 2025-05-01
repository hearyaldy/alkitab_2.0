// lib/services/bible_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alkitab_2_0/models/bible_model.dart';

class BibleService {
  static const versionUrls = {
    'ABB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tm.json',
    'ATB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tb.json',
  };

  static Future<List<BibleBook>> fetchBooks(String versionCode) async {
    final local = await _getBooksFromLocal(versionCode);
    if (local.isNotEmpty) return local;

    final books = await _fetchBooksFromNetwork(versionCode);
    await _cacheBooks(versionCode, books);
    return books;
  }

  static Future<List<BibleBook>> _fetchBooksFromNetwork(
      String versionCode) async {
    final url = versionUrls[versionCode];
    if (url == null) throw Exception('Invalid version: $versionCode');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Failed to fetch books');

    final List<dynamic> verses = json.decode(response.body)['verses'];
    final Map<int, String> bookMap = {};

    for (final v in verses) {
      bookMap[v['book']] = v['book_name'];
    }

    return bookMap.entries.map((e) {
      final id = e.value.toLowerCase().replaceAll(' ', '_');
      return BibleBook(
        id: id,
        name: e.value,
        abbreviation: id.substring(0, 3),
        order: e.key,
        testament: e.key <= 39 ? 'OT' : 'NT',
        chapters: 1,
      );
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  static Future<void> _cacheBooks(
      String versionCode, List<BibleBook> books) async {
    final box = await Hive.openBox('bible_books_$versionCode');
    await box.clear();
    for (var book in books) {
      await box.put(book.id, book.toJson());
    }
  }

  static Future<List<BibleBook>> _getBooksFromLocal(String versionCode) async {
    final box = await Hive.openBox('bible_books_$versionCode');
    return box.values
        .map((e) => BibleBook.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<BibleVerse>> fetchVerses({
    required String bookId,
    required int chapterId,
    String version = 'ABB',
  }) async {
    final local = await _getVersesFromLocal(bookId, chapterId, version);
    if (local.isNotEmpty) return local;

    final verses = await _fetchVersesFromNetwork(bookId, chapterId, version);
    await _cacheVerses(bookId, chapterId, version, verses);
    return verses;
  }

  static Future<List<BibleVerse>> _fetchVersesFromNetwork(
    String bookId,
    int chapterId,
    String version,
  ) async {
    final url = versionUrls[version];
    if (url == null) throw Exception('Invalid version: $version');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Failed to fetch verses');

    final data = json.decode(response.body);
    final List<dynamic> all = data['verses'];

    final bookNum = _getBookNumber(bookId);
    final filtered =
        all.where((v) => v['book'] == bookNum && v['chapter'] == chapterId);

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

  static Future<void> _cacheVerses(
    String bookId,
    int chapterId,
    String version,
    List<BibleVerse> verses,
  ) async {
    final box =
        await Hive.openBox('bible_verses_${version}_${bookId}_$chapterId');
    await box.clear();
    for (var v in verses) {
      await box.put(v.verseNumber, v.toJson());
    }
  }

  static Future<List<BibleVerse>> _getVersesFromLocal(
    String bookId,
    int chapterId,
    String version,
  ) async {
    final box =
        await Hive.openBox('bible_verses_${version}_${bookId}_$chapterId');
    return box.values
        .map((e) => BibleVerse.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int _getBookNumber(String bookId) {
    const bookMap = {
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
      'matt': 40,
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
    return bookMap[bookId] ?? 1;
  }
}
