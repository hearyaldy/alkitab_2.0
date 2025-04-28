// lib/services/bookmark_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/bookmark_model.dart';
import '../services/sync_queue_processor.dart';

class BookmarkService {
  final SyncQueueProcessor _syncQueueProcessor;

  BookmarkService(this._syncQueueProcessor);

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<BookmarkModel>> getUserBookmarks({String? type}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      var query =
          _supabase.from('user_bookmarks').select().eq('user_id', user.id);
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

      final bookmarkData = {
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
      };

      final response = await _supabase
          .from('user_bookmarks')
          .upsert(bookmarkData)
          .select()
          .single();

      return BookmarkModel.fromJson(response);
    } catch (e) {
      debugPrint('Bookmark add error: $e');
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
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
        },
      );
      return null;
    }
  }

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
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
          'id': bookmarkId,
          'operation': 'delete',
        },
      );
      return false;
    }
  }

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
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
          'id': id,
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
          'operation': 'update',
        },
      );
      return null;
    }
  }

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
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
          'type': type,
          'operation': 'fetch',
        },
      );
      return [];
    }
  }

  Future<BookmarkModel?> getBookmarkById(String bookmarkId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('user_bookmarks')
          .select()
          .eq('id', bookmarkId)
          .eq('user_id', user.id)
          .single();

      return BookmarkModel.fromJson(response);
    } catch (e) {
      debugPrint('Bookmark fetch by ID error: $e');
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
          'id': bookmarkId,
          'operation': 'fetch_by_id',
        },
      );
      return null;
    }
  }

  Future<List<BookmarkModel>> bulkAddBookmarks(
      List<BookmarkModel> bookmarks) async {
    final successfulBookmarks = <BookmarkModel>[];

    for (var bookmark in bookmarks) {
      try {
        final result = await addBookmark(
          title: bookmark.title,
          verseReference: bookmark.verseReference,
          verseText: bookmark.verseText,
          bookmarkType: bookmark.bookmarkType,
          type: bookmark.type,
          bookId: bookmark.bookId,
          chapterId: bookmark.chapterId,
          verseId: bookmark.verseId,
          notes: bookmark.notes,
          devotionalText: bookmark.devotionalText,
          reflectionQuestions: bookmark.reflectionQuestions,
          prayer: bookmark.prayer,
        );

        if (result != null) {
          successfulBookmarks.add(result);
        }
      } catch (e) {
        debugPrint('Bulk bookmark add error: $e');
      }
    }

    return successfulBookmarks;
  }

  Future<void> processBookmarkSyncQueue() async {
    try {
      final syncQueueProcessor = _syncQueueProcessor;
      await syncQueueProcessor.processQueue();
    } catch (e) {
      debugPrint('Bookmark sync queue processing error: $e');
    }
  }
}

extension BookmarkUtilities on BookmarkService {
  String convertBookmarkToShareableText(BookmarkModel bookmark) {
    final buffer = StringBuffer();

    if (bookmark.title != null) {
      buffer.writeln(bookmark.title);
    }

    if (bookmark.verseReference != null) {
      buffer.writeln(bookmark.verseReference);
    }

    if (bookmark.verseText != null) {
      buffer.writeln('"${bookmark.verseText}"');
    }

    if (bookmark.notes != null) {
      buffer.writeln('\nNotes: ${bookmark.notes}');
    }

    buffer.writeln('\nBookmarked in Alkitab 2.0');

    return buffer.toString();
  }
}
