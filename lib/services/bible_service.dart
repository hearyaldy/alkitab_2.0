import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/firebase_service.dart';

class BibleService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for verses to avoid repeated API calls
  final Map<String, List<BibleVerse>> _verseCache = {};
  final Map<String, Map<String, dynamic>> _assetBibleCache = {};

  // Current translation state
  String _currentTranslation = 'indo_tb';

  // Available translations
  final List<Map<String, String>> _availableTranslations = [
    {'id': 'indo_tb', 'name': 'Terjemahan Baru', 'language': 'Indonesian'},
    {'id': 'indo_tm', 'name': 'Terjemahan Masa Kini', 'language': 'Indonesian'},
  ];

  // Getters for compatibility
  String getCurrentTranslation() => _currentTranslation;
  List<Map<String, String>> get availableTranslations => _availableTranslations;

  // Setter for current translation
  void setCurrentTranslation(String translationId) {
    if (_availableTranslations.any((t) => t['id'] == translationId)) {
      _currentTranslation = translationId;
      // Clear verse cache when translation changes
      _verseCache.clear();
    }
  }

  // Add fetchVerses method for compatibility
  Future<List<BibleVerse>> fetchVerses(String bookId, int chapterId) async {
    return getChapterVerses(bookId, chapterId);
  }

  // Load Bible data from assets
  Future<Map<String, dynamic>> _loadBibleFromAssets(
      String translationId) async {
    if (_assetBibleCache.containsKey(translationId)) {
      return _assetBibleCache[translationId]!;
    }

    try {
      final String assetPath = 'assets/bibles/$translationId.json';
      final String response = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> bibleData = json.decode(response);

      _assetBibleCache[translationId] = bibleData;
      return bibleData;
    } catch (e) {
      debugPrint('Error loading Bible from assets ($translationId): $e');
      return {};
    }
  }

  // Get verses for a specific chapter
  Future<List<BibleVerse>> getChapterVerses(
    String bookId,
    int chapterId,
  ) async {
    final cacheKey = '${_currentTranslation}_${bookId}_$chapterId';

    // Return cached data if available
    if (_verseCache.containsKey(cacheKey)) {
      return _verseCache[cacheKey]!;
    }

    try {
      // First, try to load from assets
      final verses = await _loadFromAssets(bookId, chapterId);
      if (verses.isNotEmpty) {
        _verseCache[cacheKey] = verses;
        return verses;
      }

      // Fallback to local storage
      final localVerses = await _loadFromLocalStorage(cacheKey);
      if (localVerses.isNotEmpty) {
        _verseCache[cacheKey] = localVerses;
        return localVerses;
      }

      // Last resort: try Firebase Firestore (for compatibility)
      final querySnapshot = await _firestore
          .collection('bible_verses')
          .where('book_id', isEqualTo: bookId)
          .where('chapter_id', isEqualTo: chapterId)
          .orderBy('verse_id')
          .get();

      final List<BibleVerse> result = [];

      for (final doc in querySnapshot.docs) {
        result.add(BibleVerse.fromJson(doc.data()));
      }

      // Cache the data
      _verseCache[cacheKey] = result;

      // Save to local storage for offline access
      _saveToLocalStorage(cacheKey, result);

      return result;
    } catch (e) {
      debugPrint('Error fetching verses: $e');

      // Final fallback to local storage if available
      final verses = await _loadFromLocalStorage(cacheKey);
      if (verses.isNotEmpty) {
        return verses;
      }

      return [];
    }
  }

  // Load verses from assets
  Future<List<BibleVerse>> _loadFromAssets(String bookId, int chapterId) async {
    try {
      final bibleData = await _loadBibleFromAssets(_currentTranslation);
      final List<dynamic> verses = bibleData['verses'] ?? [];

      // Convert book ID to book number for filtering
      final bookNumber = _getBookNumber(bookId);
      if (bookNumber == -1) return [];

      final List<BibleVerse> result = [];

      for (final verseData in verses) {
        if (verseData['book'] == bookNumber &&
            verseData['chapter'] == chapterId) {
          result.add(BibleVerse(
            id: verseData['verse'] ?? 1,
            bookId: bookId,
            chapterId: chapterId,
            verseNumber: verseData['verse'] ?? 1,
            text: verseData['text'] ?? '',
          ));
        }
      }

      // Sort by verse number
      result.sort((a, b) => a.verseId.compareTo(b.verseId));

      debugPrint(
          'Loaded ${result.length} verses from assets for $bookId $chapterId');
      return result;
    } catch (e) {
      debugPrint('Error loading verses from assets: $e');
      return [];
    }
  }

  // Get metadata for the current translation
  Future<Map<String, dynamic>?> getCurrentTranslationMetadata() async {
    try {
      final bibleData = await _loadBibleFromAssets(_currentTranslation);
      return bibleData['metadata'];
    } catch (e) {
      debugPrint('Error loading metadata: $e');
      return null;
    }
  }

  // Convert book ID to book number
  int _getBookNumber(String bookId) {
    final book = bibleBooks.firstWhere(
      (b) => b['id'] == bookId,
      orElse: () => {},
    );

    if (book.isEmpty) return -1;

    // Find the index in the bible books list + 1 (since books are numbered from 1)
    return bibleBooks.indexOf(book) + 1;
  }

  // Save verses to local storage
  Future<void> _saveToLocalStorage(String key, List<BibleVerse> verses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = verses.map((verse) => verse.toJson()).toList();
      await prefs.setString('bible_verses_$key', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving verses to local storage: $e');
    }
  }

  // Load verses from local storage
  Future<List<BibleVerse>> _loadFromLocalStorage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('bible_verses_$key');

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        return jsonList.map((item) => BibleVerse.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading verses from local storage: $e');
    }

    return [];
  }

  // Search the Bible for a specific term
  Future<List<BibleVerse>> searchBible(String term) async {
    if (term.isEmpty) return [];

    try {
      // Note: Firestore doesn't have full-text search like Supabase
      // For now, this will search for exact matches or contains
      // For better search functionality, consider using Algolia or similar
      final querySnapshot = await _firestore
          .collection('bible_verses')
          .where('text', isGreaterThanOrEqualTo: term)
          .where('text', isLessThan: '$term\uf8ff')
          .limit(100)
          .get();

      return querySnapshot.docs
          .map<BibleVerse>((doc) => BibleVerse.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching Bible: $e');
      return [];
    }
  }

  // Get bookmarked verses for the current user
  Future<List<BibleVerse>> getBookmarkedVerses() async {
    final user = _firebaseService.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('user_bookmarks')
          .where('user_id', isEqualTo: user.uid)
          .where('type', isEqualTo: 'bible')
          .where('bookmark_type', isEqualTo: 'bible_verse')
          .orderBy('created_at', descending: true)
          .get();

      List<BibleVerse> verses = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final bookId = data['book_id'];
        final chapterId = data['chapter_id'];
        final verseId = data['verse_id'];

        if (verseId != null) {
          final verseSnapshot = await _firestore
              .collection('bible_verses')
              .where('book_id', isEqualTo: bookId)
              .where('chapter_id', isEqualTo: chapterId)
              .where('verse_id', isEqualTo: verseId)
              .get();

          if (verseSnapshot.docs.isNotEmpty) {
            verses.add(BibleVerse.fromJson(verseSnapshot.docs.first.data()));
          }
        }
      }

      return verses;
    } catch (e) {
      debugPrint('Error fetching bookmarked verses: $e');
      return [];
    }
  }

  // Get bookmarked chapters for the current user
  Future<List<Map<String, dynamic>>> getBookmarkedChapters() async {
    final user = _firebaseService.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('user_bookmarks')
          .where('user_id', isEqualTo: user.uid)
          .where('type', isEqualTo: 'bible')
          .where('bookmark_type', isEqualTo: 'bible_chapter')
          .where('verse_id', isNull: true)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map<Map<String, dynamic>>((doc) {
        final data = doc.data();
        return {
          'book_id': data['book_id'],
          'chapter_id': data['chapter_id'],
          'book_name': bibleBooks.firstWhere(
            (book) => book['id'] == data['book_id'],
            orElse: () => {'name': data['book_id']},
          )['name'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching bookmarked chapters: $e');
      return [];
    }
  }

  // Sync local bookmarks with Firebase
  Future<void> syncBookmarks() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      // Load local bookmarks
      final prefs = await SharedPreferences.getInstance();
      final chapterBookmarks =
          prefs.getStringList('bible_chapter_bookmarks') ?? [];
      final verseBookmarks = prefs.getStringList('bible_verse_bookmarks') ?? [];

      // Fetch remote bookmarks
      final querySnapshot = await _firestore
          .collection('user_bookmarks')
          .where('user_id', isEqualTo: user.uid)
          .where('type', isEqualTo: 'bible')
          .get();

      final remoteBookmarks =
          querySnapshot.docs.map((doc) => doc.data()).toList();

      // Process chapter bookmarks
      for (final bookmark in chapterBookmarks) {
        final parts = bookmark.split('_');
        if (parts.length != 2) continue;

        final bookId = parts[0];
        final chapterId = int.parse(parts[1]);

        // Check if already exists remotely
        final exists = remoteBookmarks.any((b) =>
            b['book_id'] == bookId &&
            b['chapter_id'] == chapterId &&
            b['verse_id'] == null &&
            b['bookmark_type'] == 'bible_chapter');

        if (!exists) {
          // Add to remote
          await _firestore.collection('user_bookmarks').add({
            'user_id': user.uid,
            'type': 'bible',
            'bookmark_type': 'bible_chapter',
            'book_id': bookId,
            'chapter_id': chapterId,
            'verse_id': null,
            'verse_reference': '$bookId $chapterId',
            'title': 'Bible - $bookId $chapterId',
            'created_at': Timestamp.now(),
          });
        }
      }

      // Process verse bookmarks
      for (final bookmark in verseBookmarks) {
        final parts = bookmark.split('_');
        if (parts.length != 3) continue;

        final bookId = parts[0];
        final chapterId = int.parse(parts[1]);
        final verseId = int.parse(parts[2]);

        // Check if already exists remotely
        final exists = remoteBookmarks.any((b) =>
            b['book_id'] == bookId &&
            b['chapter_id'] == chapterId &&
            b['verse_id'] == verseId &&
            b['bookmark_type'] == 'bible_verse');

        if (!exists) {
          // Add to remote
          await _firestore.collection('user_bookmarks').add({
            'user_id': user.uid,
            'type': 'bible',
            'bookmark_type': 'bible_verse',
            'book_id': bookId,
            'chapter_id': chapterId,
            'verse_id': verseId,
            'verse_reference': '$bookId $chapterId:$verseId',
            'title': 'Bible - $bookId $chapterId:$verseId',
            'created_at': Timestamp.now(),
          });
        }
      }

      // Now check for remote bookmarks that need to be added locally
      List<String> newChapterBookmarks = List.from(chapterBookmarks);
      List<String> newVerseBookmarks = List.from(verseBookmarks);

      for (final bookmark in remoteBookmarks) {
        final bookId = bookmark['book_id'];
        final chapterId = bookmark['chapter_id'];
        final verseId = bookmark['verse_id'];
        final bookmarkType = bookmark['bookmark_type'];

        if (bookmarkType == 'bible_chapter' && verseId == null) {
          final key = '${bookId}_$chapterId';
          if (!newChapterBookmarks.contains(key)) {
            newChapterBookmarks.add(key);
          }
        } else if (bookmarkType == 'bible_verse' && verseId != null) {
          final key = '${bookId}_${chapterId}_$verseId';
          if (!newVerseBookmarks.contains(key)) {
            newVerseBookmarks.add(key);
          }
        }
      }

      // Save updated local bookmarks
      if (newChapterBookmarks.length != chapterBookmarks.length) {
        await prefs.setStringList(
            'bible_chapter_bookmarks', newChapterBookmarks);
      }

      if (newVerseBookmarks.length != verseBookmarks.length) {
        await prefs.setStringList('bible_verse_bookmarks', newVerseBookmarks);
      }
    } catch (e) {
      debugPrint('Error syncing bookmarks: $e');
    }
  }
}
