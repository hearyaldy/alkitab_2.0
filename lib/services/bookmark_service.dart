// lib/services/bookmark_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/constants.dart';
import '../models/bookmark_model.dart';
import '../services/connectivity_service.dart';
import '../services/sync_queue_processor.dart';
import '../utils/offline_manager.dart';
import '../utils/sync_conflict_resolver.dart';

class BookmarkService {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineManager _offlineManager = OfflineManager();
  final Uuid _uuid = const Uuid();

  static const String _bookmarksBoxName = 'bookmarks';

  BookmarkService(this._syncQueueProcessor);

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<BookmarkModel>> getUserBookmarks({String? type}) async {
    final localBookmarks = await _getLocalBookmarks(type: type);

    if (_connectivityService.isOnline) {
      try {
        final serverBookmarks = await _getServerBookmarks(type: type);
        final mergedBookmarks =
            _mergeBookmarks(localBookmarks, serverBookmarks);
        await _saveBookmarksToLocalStorage(mergedBookmarks);
        await processBookmarkSyncQueue();
        return mergedBookmarks;
      } catch (e) {
        debugPrint('Server bookmarks fetch error: $e');
      }
    }
    return localBookmarks;
  }

  Future<List<BookmarkModel>> _getLocalBookmarks({String? type}) async {
    await _openBookmarksBoxIfNeeded();
    final box = Hive.box(_bookmarksBoxName);
    final bookmarks = <BookmarkModel>[];

    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        try {
          final bookmark = BookmarkModel.fromJson(
            value is String ? jsonDecode(value) : value,
          );
          if (type == null ||
              bookmark.type == type ||
              bookmark.bookmarkType == type) {
            bookmarks.add(bookmark);
          }
        } catch (e) {
          debugPrint('Error parsing bookmark from local: $e');
        }
      }
    }
    return bookmarks;
  }

  Future<List<BookmarkModel>> _getServerBookmarks({String? type}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    var query =
        _supabase.from('user_bookmarks').select().eq('user_id', user.id);
    if (type != null) query = query.eq('type', type);

    final response = await query;
    final bookmarks =
        response.map<BookmarkModel>((e) => BookmarkModel.fromJson(e)).toList();
    await _offlineManager.updateContentTimestamp('bookmarks');
    return bookmarks;
  }

  Future<void> _saveBookmarksToLocalStorage(
      List<BookmarkModel> bookmarks) async {
    await _openBookmarksBoxIfNeeded();
    final box = Hive.box(_bookmarksBoxName);
    await box.clear();
    for (var bookmark in bookmarks) {
      await box.put(bookmark.id, jsonEncode(bookmark.toJson()));
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
    final userId = _supabase.auth.currentUser?.id ?? 'offline_user';
    final bookmarkId = _uuid.v4();
    final data = {
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

    final bookmark = BookmarkModel.fromJson(data);

    await _openBookmarksBoxIfNeeded();
    final box = Hive.box(_bookmarksBoxName);
    await box.put(bookmarkId, jsonEncode(data));

    if (_connectivityService.isOnline) {
      try {
        final uploadData = {...data}..remove('operation');
        final response = await _supabase
            .from('user_bookmarks')
            .upsert(uploadData)
            .select()
            .single();
        await box.put(
            bookmarkId, jsonEncode({...data, ...response, 'is_synced': true}));
        return BookmarkModel.fromJson(response);
      } catch (e) {
        await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.bookmark, data: data);
      }
    } else {
      await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.bookmark, data: data);
    }
    return bookmark;
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
    await _openBookmarksBoxIfNeeded();
    final box = Hive.box(_bookmarksBoxName);
    final existing = box.get(id);

    if (existing == null) {
      debugPrint('Bookmark not found for update: $id');
      return null;
    }

    final existingData = jsonDecode(existing);

    final updatedData = {
      ...existingData,
      'title': title ?? existingData['title'],
      'verse_reference': verseReference ?? existingData['verse_reference'],
      'verse_text': verseText ?? existingData['verse_text'],
      'bookmark_type': bookmarkType ?? existingData['bookmark_type'],
      'type': type ?? existingData['type'],
      'book_id': bookId ?? existingData['book_id'],
      'chapter_id': chapterId ?? existingData['chapter_id'],
      'verse_id': verseId ?? existingData['verse_id'],
      'notes': notes ?? existingData['notes'],
      'devotional_text': devotionalText ?? existingData['devotional_text'],
      'reflection_questions':
          reflectionQuestions ?? existingData['reflection_questions'],
      'prayer': prayer ?? existingData['prayer'],
      'last_modified': DateTime.now().toIso8601String(),
      'is_synced': false,
    };

    await box.put(id, jsonEncode(updatedData));

    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final uploadData = {...updatedData}..remove('operation');
          final response = await _supabase
              .from('user_bookmarks')
              .update(uploadData)
              .eq('id', id)
              .eq('user_id', user.id)
              .select()
              .single();

          await box.put(
              id, jsonEncode({...uploadData, ...response, 'is_synced': true}));
          return BookmarkModel.fromJson(response);
        }
      } catch (e) {
        debugPrint('Server bookmark update error: $e');
        await _syncQueueProcessor.addToQueue(
          type: SyncOperationType.bookmark,
          data: {...updatedData, 'operation': 'update'},
        );
      }
    } else {
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {...updatedData, 'operation': 'update'},
      );
    }

    return BookmarkModel.fromJson(updatedData.cast<String, dynamic>());
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    await _openBookmarksBoxIfNeeded();
    final box = Hive.box(_bookmarksBoxName);
    await box.delete(bookmarkId);

    if (_connectivityService.isOnline) {
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase
              .from('user_bookmarks')
              .delete()
              .eq('id', bookmarkId)
              .eq('user_id', user.id);
        } else {
          await _syncQueueProcessor.addToQueue(
              type: SyncOperationType.bookmark,
              data: {'id': bookmarkId, 'operation': 'delete'});
        }
        return true;
      } catch (e) {
        await _syncQueueProcessor.addToQueue(
            type: SyncOperationType.bookmark,
            data: {'id': bookmarkId, 'operation': 'delete'});
      }
    }
    return true;
  }

  Future<void> _openBookmarksBoxIfNeeded() async {
    if (!Hive.isBoxOpen(_bookmarksBoxName)) {
      await Hive.openBox(_bookmarksBoxName);
    }
  }

  List<BookmarkModel> _mergeBookmarks(
      List<BookmarkModel> local, List<BookmarkModel> server) {
    final Map<String, BookmarkModel> map = {for (var b in server) b.id: b};
    for (var localBookmark in local) {
      final id = localBookmark.id;
      if (map.containsKey(id)) {
        final serverBookmark = map[id]!;
        if (localBookmark.toJson()['is_synced'] == true) {
          continue;
        }
        final resolved = SyncConflictResolver.resolveConflict(
          localData: Map<String, dynamic>.from(localBookmark.toJson()),
          cloudData: Map<String, dynamic>.from(serverBookmark.toJson()),
          dataType: 'bookmarks',
        );
        map[id] = BookmarkModel.fromJson(resolved);
      } else {
        map[id] = localBookmark;
      }
    }
    return map.values.toList();
  }

  Future<void> processBookmarkSyncQueue() async {
    if (!_connectivityService.isOnline) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _syncQueueProcessor.processQueue();
    await _offlineManager.updateContentTimestamp('bookmarks');
  }
}

extension BookmarkUtilities on BookmarkService {
  String convertBookmarkToShareableText(BookmarkModel bookmark) {
    final buffer = StringBuffer();
    if (bookmark.title != null) buffer.writeln(bookmark.title);
    if (bookmark.verseReference != null) {
      buffer.writeln(bookmark.verseReference);
    }
    if (bookmark.verseText != null) buffer.writeln('"${bookmark.verseText}"');
    if (bookmark.notes != null) buffer.writeln('\nNotes: ${bookmark.notes}');
    buffer.writeln('\nBookmarked in Alkitab 2.0');
    return buffer.toString();
  }

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
