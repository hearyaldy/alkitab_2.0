import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';

class BibleService {
  final supabase = Supabase.instance.client;

  // Cache for verses to avoid repeated API calls
  final Map<String, List<BibleVerse>> _verseCache = {};

  // Get verses for a specific chapter
  Future<List<BibleVerse>> getChapterVerses(
    String bookId,
    int chapterId,
  ) async {
    final cacheKey = '${bookId}_$chapterId';

    // Return cached data if available
    if (_verseCache.containsKey(cacheKey)) {
      return _verseCache[cacheKey]!;
    }

    try {
      // Try to load from local storage first
      final verses = await _loadFromLocalStorage(cacheKey);
      if (verses.isNotEmpty) {
        _verseCache[cacheKey] = verses;
        return verses;
      }

      // If not in local storage, fetch from Supabase
      final response = await supabase
          .from('bible_verses')
          .select()
          .eq('book_id', bookId)
          .eq('chapter_id', chapterId)
          .order('verse_id');

      final List<BibleVerse> result = [];

      for (final item in response) {
        result.add(BibleVerse.fromJson(item));
      }

      // Cache the data
      _verseCache[cacheKey] = result;

      // Save to local storage for offline access
      _saveToLocalStorage(cacheKey, result);

      return result;
    } catch (e) {
      debugPrint('Error fetching verses: $e');

      // Fallback to local storage if available
      final verses = await _loadFromLocalStorage(cacheKey);
      if (verses.isNotEmpty) {
        return verses;
      }

      return [];
    }
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
      final response = await supabase
          .from('bible_verses')
          .select()
          .textSearch('text', term)
          .limit(100);

      return response
          .map<BibleVerse>((item) => BibleVerse.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('Error searching Bible: $e');
      return [];
    }
  }

  // Get bookmarked verses for the current user
  Future<List<BibleVerse>> getBookmarkedVerses() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('user_bookmarks')
          .select('book_id, chapter_id, verse_id')
          .eq('user_id', user.id)
          .eq('type', 'bible')
          .eq('bookmark_type', 'bible_verse')
          .order('created_at', ascending: false);

      List<BibleVerse> verses = [];
      for (final bookmark in response) {
        final bookId = bookmark['book_id'];
        final chapterId = bookmark['chapter_id'];
        final verseId = bookmark['verse_id'];

        if (verseId != null) {
          final verseResponse = await supabase
              .from('bible_verses')
              .select()
              .eq('book_id', bookId)
              .eq('chapter_id', chapterId)
              .eq('verse_id', verseId)
              .single();

          verses.add(BibleVerse.fromJson(verseResponse));
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
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('user_bookmarks')
          .select('book_id, chapter_id')
          .eq('user_id', user.id)
          .eq('type', 'bible')
          .eq('bookmark_type', 'bible_chapter')
          .isFilter('verse_id', null)
          .order('created_at', ascending: false);

      return response
          .map<Map<String, dynamic>>((item) => {
                'book_id': item['book_id'],
                'chapter_id': item['chapter_id'],
                'book_name': bibleBooks.firstWhere(
                  (book) => book['id'] == item['book_id'],
                  orElse: () => {'name': item['book_id']},
                )['name'],
              })
          .toList();
    } catch (e) {
      debugPrint('Error fetching bookmarked chapters: $e');
      return [];
    }
  }

  // Sync local bookmarks with Supabase
  Future<void> syncBookmarks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Load local bookmarks
      final prefs = await SharedPreferences.getInstance();
      final chapterBookmarks =
          prefs.getStringList('bible_chapter_bookmarks') ?? [];
      final verseBookmarks = prefs.getStringList('bible_verse_bookmarks') ?? [];

      // Fetch remote bookmarks
      final remoteBookmarks = await supabase
          .from('user_bookmarks')
          .select('book_id, chapter_id, verse_id, bookmark_type')
          .eq('user_id', user.id)
          .eq('type', 'bible');

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
          await supabase.from('user_bookmarks').insert({
            'user_id': user.id,
            'type': 'bible',
            'bookmark_type': 'bible_chapter',
            'book_id': bookId,
            'chapter_id': chapterId,
            'verse_id': null,
            'verse_reference': '$bookId $chapterId',
            'title': 'Bible - $bookId $chapterId',
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
          await supabase.from('user_bookmarks').insert({
            'user_id': user.id,
            'type': 'bible',
            'bookmark_type': 'bible_verse',
            'book_id': bookId,
            'chapter_id': chapterId,
            'verse_id': verseId,
            'verse_reference': '$bookId $chapterId:$verseId',
            'title': 'Bible - $bookId $chapterId:$verseId',
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
