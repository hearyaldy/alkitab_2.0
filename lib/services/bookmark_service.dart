// lib/services/bookmark_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/bookmark_model.dart';
import '../services/sync_queue_processor.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_manager.dart';
import '../utils/sync_conflict_resolver.dart';
import '../config/constants.dart';

class BookmarkService {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();
  final Uuid _uuid = const Uuid();

  // Box name for local storage
  static const String _bookmarksBoxName = 'bookmarks';

  BookmarkService(this._syncQueueProcessor);

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get user bookmarks with offline-first approach
  Future<List<BookmarkModel>> getUserBookmarks({String? type}) async {
    // First try to get bookmarks from local storage
    final localBookmarks = await _getLocalBookmarks(type: type);

    // If online, also fetch from server and merge
    if (_connectivityService.isOnline) {
      try {
        final serverBookmarks = await _getServerBookmarks(type: type);

        // Merge local and server bookmarks with conflict resolution
        final mergedBookmarks =
            _mergeBookmarks(localBookmarks, serverBookmarks);

        // Update local cache with merged bookmarks
        await _saveBookmarksToLocalStorage(mergedBookmarks);

        // Process any pending sync queue items
        await processBookmarkSyncQueue();

        return mergedBookmarks;
      } catch (e) {
        debugPrint('Server bookmarks fetch error: $e');
        // If server fetch fails, return local bookmarks
        return localBookmarks;
      }
    }

    return localBookmarks;
  }

  /// Get bookmarks from local storage
  Future<List<BookmarkModel>> _getLocalBookmarks({String? type}) async {
    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);
      final List<BookmarkModel> bookmarks = [];

      // Convert all stored bookmarks to BookmarkModel objects
      for (var key in box.keys) {
        final json = box.get(key);
        if (json != null) {
          try {
            final bookmark = BookmarkModel.fromJson(
              json is String ? jsonDecode(json) : json,
            );

            // Filter by type if specified
            if (type == null ||
                bookmark.type == type ||
                bookmark.bookmarkType == type) {
              bookmarks.add(bookmark);
            }
          } catch (e) {
            debugPrint('Error parsing bookmark from local storage: $e');
          }
        }
      }

      return bookmarks;
    } catch (e) {
      debugPrint('Local bookmarks fetch error: $e');
      return [];
    }
  }

  /// Get bookmarks from server
  Future<List<BookmarkModel>> _getServerBookmarks({String? type}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      var query =
          _supabase.from('user_bookmarks').select().eq('user_id', user.id);
      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query;
      final bookmarks = response
          .map<BookmarkModel>((json) => BookmarkModel.fromJson(json))
          .toList();

      // Update timestamp for bookmark content
      await _offlineManager.updateContentTimestamp('bookmarks');

      return bookmarks;
    } catch (e) {
      debugPrint('Server bookmarks fetch error: $e');
      throw e; // Re-throw to handle in calling method
    }
  }

  /// Save bookmarks to local storage
  Future<void> _saveBookmarksToLocalStorage(
      List<BookmarkModel> bookmarks) async {
    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);

      // Clear existing bookmarks and save new ones
      await box.clear();

      for (var bookmark in bookmarks) {
        await box.put(bookmark.id, bookmark.toJson());
      }
    } catch (e) {
      debugPrint('Error saving bookmarks to local storage: $e');
    }
  }

  /// Add a bookmark with offline support
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
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'offline_user';

    // Generate a unique ID for the bookmark
    final bookmarkId = _uuid.v4();

    // Create bookmark data
    final bookmarkData = {
      'id': bookmarkId,
      'user_id': userId,
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
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': false,
      'operation': 'add',
    };

    // Create bookmark model
    final bookmark = BookmarkModel.fromJson(bookmarkData);

    // Save to local storage first
    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);
      await box.put(bookmarkId, bookmarkData);
    } catch (e) {
      debugPrint('Error saving bookmark to local storage: $e');
      return null;
    }

    // If online, try to sync with server
    if (_connectivityService.isOnline && user != null) {
      try {
        final dataToUpsert = Map<String, dynamic>.from(bookmarkData);
        dataToUpsert.remove('operation');

        final response = await _supabase
            .from('user_bookmarks')
            .upsert(dataToUpsert)
            .select()
            .single();

        // Update local storage with server response
        if (!Hive.isBoxOpen(_bookmarksBoxName)) {
          await Hive.openBox(_bookmarksBoxName);
        }

        final box = Hive.box(_bookmarksBoxName);
        final updatedData = {...bookmarkData, ...response, 'is_synced': true};
        await box.put(bookmarkId, updatedData);

        return BookmarkModel.fromJson(response);
      } catch (e) {
        debugPrint('Server bookmark add error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.bookmark,
          data: bookmarkData,
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: bookmarkData,
      );
    }

    return bookmark;
  }

  /// Delete a bookmark with offline support
  Future<bool> deleteBookmark(String bookmarkId) async {
    // Delete from local storage first
    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);
      await box.delete(bookmarkId);
    } catch (e) {
      debugPrint('Error deleting bookmark from local storage: $e');
      return false;
    }

    // If online, try to delete from server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          // Add to sync queue for when user logs in
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.bookmark,
            data: {
              'id': bookmarkId,
              'operation': 'delete',
            },
          );
          return true;
        }

        await _supabase
            .from('user_bookmarks')
            .delete()
            .eq('id', bookmarkId)
            .eq('user_id', user.id);

        return true;
      } catch (e) {
        debugPrint('Server bookmark delete error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.bookmark,
          data: {
            'id': bookmarkId,
            'operation': 'delete',
          },
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
          'id': bookmarkId,
          'operation': 'delete',
        },
      );
    }

    return true;
  }

  /// Update a bookmark with offline support
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
    // Get existing bookmark from local storage
    BookmarkModel? existingBookmark;
    Map<String, dynamic>? existingData;

    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);
      existingData = box.get(id);

      if (existingData != null) {
        existingBookmark = BookmarkModel.fromJson(
          existingData is String ? jsonDecode(existingData) : existingData,
        );
      }
    } catch (e) {
      debugPrint('Error getting existing bookmark: $e');
    }

    if (existingBookmark == null && existingData == null) {
      debugPrint('Bookmark not found: $id');
      return null;
    }

    // Prepare update data
    final updateData = <String, dynamic>{
      ...existingData ?? {},
      'id': id,
      'is_synced': false,
      'operation': 'update',
    };

    if (title != null) updateData['title'] = title;
    if (verseReference != null) updateData['verse_reference'] = verseReference;
    if (verseText != null) updateData['verse_text'] = verseText;
    if (bookmarkType != null) updateData['bookmark_type'] = bookmarkType;
    if (type != null) updateData['type'] = type;
    if (bookId != null) updateData['book_id'] = bookId;
    if (chapterId != null) updateData['chapter_id'] = chapterId;
    if (verseId != null) updateData['verse_id'] = verseId;
    if (notes != null) updateData['notes'] = notes;
    if (devotionalText != null) updateData['devotional_text'] = devotionalText;
    if (reflectionQuestions != null)
      updateData['reflection_questions'] = reflectionQuestions;
    if (prayer != null) updateData['prayer'] = prayer;

    // Update last_modified timestamp
    updateData['last_modified'] = DateTime.now().toIso8601String();

    // Update local storage
    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);
      await box.put(id, updateData);
    } catch (e) {
      debugPrint('Error updating bookmark in local storage: $e');
      return null;
    }

    // If online, try to update on server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          // Add to sync queue for when user logs in
          await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.bookmark,
            data: updateData,
          );
          return BookmarkModel.fromJson(updateData);
        }

        final dataToUpsert = Map<String, dynamic>.from(updateData);
        dataToUpsert.remove('operation');

        final response = await _supabase
            .from('user_bookmarks')
            .update(dataToUpsert)
            .eq('id', id)
            .eq('user_id', user.id)
            .select()
            .single();

        // Update local storage with server response
        if (!Hive.isBoxOpen(_bookmarksBoxName)) {
          await Hive.openBox(_bookmarksBoxName);
        }

        final box = Hive.box(_bookmarksBoxName);
        final updatedData = {...updateData, ...response, 'is_synced': true};
        updatedData.remove('operation');
        await box.put(id, updatedData);

        return BookmarkModel.fromJson(response);
      } catch (e) {
        debugPrint('Server bookmark update error: $e');

        // Add to sync queue for later sync
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.bookmark,
          data: updateData,
        );
      }
    } else {
      // If offline, add to sync queue
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: updateData,
      );
    }

    return BookmarkModel.fromJson(updateData);
  }

  /// Get bookmarks by type with offline support
  Future<List<BookmarkModel>> getBookmarksByType(String type) async {
    return getUserBookmarks(type: type);
  }

  /// Get bookmark by ID with offline support
  Future<BookmarkModel?> getBookmarkById(String bookmarkId) async {
    // First try to get from local storage
    try {
      if (!Hive.isBoxOpen(_bookmarksBoxName)) {
        await Hive.openBox(_bookmarksBoxName);
      }

      final box = Hive.box(_bookmarksBoxName);
      final data = box.get(bookmarkId);

      if (data != null) {
        return BookmarkModel.fromJson(
          data is String ? jsonDecode(data) : data,
        );
      }
    } catch (e) {
      debugPrint('Error getting bookmark from local storage: $e');
    }

    // If not found locally and online, try server
    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) return null;

        final response = await _supabase
            .from('user_bookmarks')
            .select()
            .eq('id', bookmarkId)
            .eq('user_id', user.id)
            .single();

        // Save to local storage
        if (!Hive.isBoxOpen(_bookmarksBoxName)) {
          await Hive.openBox(_bookmarksBoxName);
        }

        final box = Hive.box(_bookmarksBoxName);
        await box.put(bookmarkId, response);

        return BookmarkModel.fromJson(response);
      } catch (e) {
        debugPrint('Server bookmark fetch by ID error: $e');
        return null;
      }
    }

    return null;
  }

  /// Add multiple bookmarks in bulk with offline support
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

  /// Process bookmark sync queue
  Future<void> processBookmarkSyncQueue() async {
    if (!_connectivityService.isOnline) {
      debugPrint('Cannot process sync queue while offline');
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('Cannot process sync queue without logged in user');
        return;
      }

      final syncQueueProcessor = _syncQueueProcessor;
      await syncQueueProcessor.processQueue();

      // Update timestamp for bookmark content
      await _offlineManager.updateContentTimestamp('bookmarks');
    } catch (e) {
      debugPrint('Bookmark sync queue processing error: $e');
    }
  }

  /// Merge local and server bookmarks with conflict resolution
  List<BookmarkModel> _mergeBookmarks(
    List<BookmarkModel> localBookmarks,
    List<BookmarkModel> serverBookmarks,
  ) {
    // Create a map of ID -> bookmark for faster lookup
    final Map<String, BookmarkModel> mergedMap = {};

    // First, add all server bookmarks to the map
    for (var bookmark in serverBookmarks) {
      mergedMap[bookmark.id] = bookmark;
    }

    // Then, handle local bookmarks
    for (var localBookmark in localBookmarks) {
      final id = localBookmark.id;

      // If bookmark exists in both local and server, resolve conflicts
      if (mergedMap.containsKey(id)) {
        final serverBookmark = mergedMap[id]!;

        // Only merge if local bookmark is not synced
        // Check if isSynced is true
        if (localBookmark.isSynced == true) {
          // Local bookmark is already synced, keep server version
          continue;
        }

        // Resolve conflict between local and server bookmark
        final localData = localBookmark.toJson();
        final serverData = serverBookmark.toJson();

        final resolvedData = SyncConflictResolver.resolveConflict(
          localData: localData,
          cloudData: serverData,
          dataType: 'bookmarks',
        );

        mergedMap[id] = BookmarkModel.fromJson(resolvedData);
      } else {
        // Bookmark only exists locally, add it to the merged map
        mergedMap[id] = localBookmark;
      }
    }

    // Convert map back to list
    return mergedMap.values.toList();
  }

  /// Check if bookmarks need to be refreshed
  Future<bool> shouldRefreshBookmarks() async {
    return _offlineManager.shouldRefreshContent('bookmarks');
  }

  /// Force refresh bookmarks from server
  Future<List<BookmarkModel>> forceRefreshBookmarks() async {
    if (!_connectivityService.isOnline) {
      return _getLocalBookmarks();
    }

    try {
      final serverBookmarks = await _getServerBookmarks();
      final localBookmarks = await _getLocalBookmarks();

      // Merge local and server bookmarks
      final mergedBookmarks = _mergeBookmarks(localBookmarks, serverBookmarks);

      // Save merged bookmarks to local storage
      await _saveBookmarksToLocalStorage(mergedBookmarks);

      return mergedBookmarks;
    } catch (e) {
      debugPrint('Error refreshing bookmarks: $e');
      return _getLocalBookmarks();
    }
  }
}

extension BookmarkUtilities on BookmarkService {
  /// Convert a bookmark to shareable text
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

  /// Check if a bookmark exists by verse reference
  Future<bool> bookmarkExistsByReference(String verseReference) async {
    try {
      final bookmarks = await getUserBookmarks();
      return bookmarks.any((b) => b.verseReference == verseReference);
    } catch (e) {
      debugPrint('Error checking bookmark existence: $e');
      return false;
    }
  }
}
