// lib/screens/bookmarks/services/bookmark_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/bookmark_model.dart';

class BookmarkService {
  final _supabase = Supabase.instance.client;

  // Fetch all bookmarks for the current user
  Future<List<BookmarkModel>> getUserBookmarks({String? type}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Base query
      var query =
          _supabase.from('user_bookmarks').select().eq('user_id', user.id);

      // Optional filtering by type
      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query;

      return response
          .map<BookmarkModel>((json) => BookmarkModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Bookmark fetch error: $e');
      return [];
    }
  }

  // Add a new bookmark
  Future<BookmarkModel?> addBookmark({
    String? title,
    String? verseReference,
    String? verseText,
    String? bookmarkType,
    String? type,
    String? bookId,
    int? chapterId,
    int? verseId,
    String? notes,
    String? devotionalText,
    Map<String, dynamic>? reflectionQuestions,
    String? prayer,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('user_bookmarks')
          .insert({
            'user_id': user.id,
            'title': title,
            'verse_reference': verseReference,
            'verse_text': verseText,
            'bookmark_type': bookmarkType,
            'type': type,
            'book_id': bookId,
            'chapter_id': chapterId,
            'verse_id': verseId,
            'notes': notes,
            'devotional_text': devotionalText,
            'reflection_questions': reflectionQuestions,
            'prayer': prayer,
          })
          .select()
          .single();

      return BookmarkModel.fromJson(response);
    } catch (e) {
      debugPrint('Bookmark add error: $e');
      return null;
    }
  }

  // Delete a bookmark
  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('user_bookmarks')
          .delete()
          .eq('id', bookmarkId)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      debugPrint('Bookmark delete error: $e');
      return false;
    }
  }

  // Update an existing bookmark
  Future<BookmarkModel?> updateBookmark({
    required String id,
    String? title,
    String? verseReference,
    String? verseText,
    String? bookmarkType,
    String? type,
    String? bookId,
    int? chapterId,
    int? verseId,
    String? notes,
    String? devotionalText,
    Map<String, dynamic>? reflectionQuestions,
    String? prayer,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Prepare update data (only include non-null values)
      final updateData = <String, dynamic>{};

      if (title != null) updateData['title'] = title;
      if (verseReference != null)
        updateData['verse_reference'] = verseReference;
      if (verseText != null) updateData['verse_text'] = verseText;
      if (bookmarkType != null) updateData['bookmark_type'] = bookmarkType;
      if (type != null) updateData['type'] = type;
      if (bookId != null) updateData['book_id'] = bookId;
      if (chapterId != null) updateData['chapter_id'] = chapterId;
      if (verseId != null) updateData['verse_id'] = verseId;
      if (notes != null) updateData['notes'] = notes;
      if (devotionalText != null)
        updateData['devotional_text'] = devotionalText;
      if (reflectionQuestions != null)
        updateData['reflection_questions'] = reflectionQuestions;
      if (prayer != null) updateData['prayer'] = prayer;

      final response = await _supabase
          .from('user_bookmarks')
          .update(updateData)
          .eq('id', id)
          .eq('user_id', user.id)
          .select()
          .single();

      return BookmarkModel.fromJson(response);
    } catch (e) {
      debugPrint('Bookmark update error: $e');
      return null;
    }
  }

  // Get bookmarks by type
  Future<List<BookmarkModel>> getBookmarksByType(String type) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_bookmarks')
          .select()
          .eq('user_id', user.id)
          .eq('type', type);

      return response
          .map<BookmarkModel>((json) => BookmarkModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Bookmark type fetch error: $e');
      return [];
    }
  }
}
