// lib/services/bookmark_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/bookmark_model.dart';
import '../services/sync_queue_processor.dart';

class BookmarkService {
  final _supabase = Supabase.instance.client;
  final SyncQueueProcessor _syncQueueProcessor;

  BookmarkService(this._syncQueueProcessor);

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

      // Try to add bookmark directly to Supabase
      final response = await _supabase
          .from('user_bookmarks')
          .upsert(bookmarkData)
          .select()
          .single();

      return BookmarkModel.fromJson(response);
    } catch (e) {
      debugPrint('Bookmark add error: $e');

      // If network fails, add to sync queue
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

      // Add delete operation to sync queue
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

      // Try to update directly in Supabase
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

      // If update fails, add to sync queue
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
      // If network fetch fails, try to get from local storage or sync queue
      debugPrint('Bookmark type fetch error: $e');

      // Optionally, add to sync queue for later retry
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

  // Retrieve a single bookmark by ID
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

      // Add to sync queue for potential later retrieval
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

  // Bulk operations with sync queue support
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
        // Automatically handled by addBookmark method's sync queue logic
      }
    }

    return successfulBookmarks;
  }

  // Check and process any pending sync queue items
  Future<void> processBookmarkSyncQueue() async {
    try {
      final syncQueueProcessor = _syncQueueProcessor;
      await syncQueueProcessor.processQueue();
    } catch (e) {
      debugPrint('Bookmark sync queue processing error: $e');
    }
  }
}

// Extension for additional bookmark-related utilities
extension BookmarkUtilities on BookmarkService {
  // Convert bookmark to shareable text
  String convertBookmarkToShareableText(BookmarkModel bookmark) {
    final buffer = StringBuffer();

    // Add title if exists
    if (bookmark.title != null) {
      buffer.writeln(bookmark.title);
    }

    // Add verse reference
    if (bookmark.verseReference != null) {
      buffer.writeln(bookmark.verseReference);
    }

    // Add verse text
    if (bookmark.verseText != null) {
      buffer.writeln('"${bookmark.verseText}"');
    }

    // Add notes if exists
    if (bookmark.notes != null) {
      buffer.writeln('\nNotes: ${bookmark.notes}');
    }

    // Add source
    buffer.writeln('\nBookmarked in Alkitab 2.0');

    return buffer.toString();
  }
}
