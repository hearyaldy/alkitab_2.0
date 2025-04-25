import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/services/local_storage_service.dart';

class BibleService {
  static const versionUrls = {
    'ABB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tm.json',
    'ATB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tb.json',
  };

  // Fetch books with offline caching
  static Future<List<BibleBook>> fetchBooks(String versionCode) async {
    // First, try to get books from local storage
    final localBooks = await _getBooksFromLocalStorage(versionCode);
    if (localBooks.isNotEmpty) {
      return localBooks;
    }

    // If not in local storage, fetch from network
    try {
      final books = await _fetchBooksFromNetwork(versionCode);

      // Cache books for offline use
      await _cacheBooksLocally(versionCode, books);

      return books;
    } catch (e) {
      debugPrint('Error fetching books: $e');
      return [];
    }
  }

  // Fetch books from network
  static Future<List<BibleBook>> _fetchBooksFromNetwork(
      String versionCode) async {
    final url = versionUrls[versionCode];
    if (url == null) throw Exception('Invalid Bible version: $versionCode');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load Bible data');
    }

    final data = json.decode(response.body);
    final List<dynamic> verses = data['verses'];

    // Group by book number and name
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
        chapters: 1, // set to 1 for now (can improve later)
      );
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // Cache books in local storage
  static Future<void> _cacheBooksLocally(
      String versionCode, List<BibleBook> books) async {
    final box = await Hive.openBox('bible_books_$versionCode');

    // Clear existing data
    await box.clear();

    // Save books
    for (var book in books) {
      await box.put(book.id, book.toJson());
    }
  }

  // Retrieve books from local storage
  static Future<List<BibleBook>> _getBooksFromLocalStorage(
      String versionCode) async {
    final box = await Hive.openBox('bible_books_$versionCode');

    return box.values
        .map((bookJson) =>
            BibleBook.fromJson(Map<String, dynamic>.from(bookJson)))
        .toList();
  }

  // Fetch verses for a specific book and chapter
  static Future<List<BibleVerse>> fetchVerses({
    required String bookId,
    required int chapterId,
    String version = 'ABB',
  }) async {
    // First, try to get verses from local storage
    final localVerses = await _getVersesFromLocalStorage(
      bookId: bookId,
      chapterId: chapterId,
      version: version,
    );

    if (localVerses.isNotEmpty) {
      return localVerses;
    }

    // If not in local storage, fetch from network
    try {
      final verses = await _fetchVersesFromNetwork(
        bookId: bookId,
        chapterId: chapterId,
        version: version,
      );

      // Cache verses for offline use
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

  // Fetch verses from network
  static Future<List<BibleVerse>> _fetchVersesFromNetwork({
    required String bookId,
    required int chapterId,
    required String version,
  }) async {
    final url = versionUrls[version];
    if (url == null) throw Exception('Invalid Bible version: $version');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load Bible verses');
    }

    final data = json.decode(response.body);
    final List<dynamic> allVerses = data['verses'];

    final bookNum = _getBookNumber(bookId);
    final filteredVerses = allVerses
        .where((v) => v['book'] == bookNum && v['chapter'] == chapterId)
        .toList();

    return filteredVerses
        .map((v) => BibleVerse(
              id: v['verse'],
              bookId: bookId,
              chapterId: chapterId,
              verseNumber: v['verse'],
              text: v['text'],
            ))
        .toList();
  }

  // Cache verses in local storage
  static Future<void> _cacheVersesLocally({
    required String bookId,
    required int chapterId,
    required String version,
    required List<BibleVerse> verses,
  }) async {
    final boxName = 'bible_verses_${version}_${bookId}_$chapterId';
    final box = await Hive.openBox(boxName);

    // Clear existing data
    await box.clear();

    // Save verses
    for (var verse in verses) {
      await box.put(verse.verseNumber, verse.toJson());
    }
  }

  // Retrieve verses from local storage
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

  // Helper method to get book number
  static int _getBookNumber(String bookId) {
    // This should match the book number in your JSON
    final bookIndexMap = {
      'genesis': 1,
      'exodus': 2,
      // ... add all your book mappings
      'revelation': 66,
    };
    return bookIndexMap[bookId] ?? 1;
  }
}
