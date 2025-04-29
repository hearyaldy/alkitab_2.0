// lib/providers/bookmark_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bookmark_model.dart';
import '../services/bookmark_service.dart';
import '../services/sync_queue_processor.dart';
import '../providers/sync_providers.dart';

// Provider for BookmarkService
final bookmarkServiceProvider = Provider<BookmarkService>((ref) {
  final syncQueueProcessor = ref.watch(syncQueueProcessorProvider);
  return BookmarkService(syncQueueProcessor);
});

// Stream provider for bookmarks with sync awareness
final bookmarksProvider = StreamProvider<List<BookmarkModel>>((ref) async* {
  final bookmarkService = ref.watch(bookmarkServiceProvider);

  final initialBookmarks = await bookmarkService.getUserBookmarks();
  yield initialBookmarks;

  await for (final _ in Stream.periodic(const Duration(minutes: 5))) {
    try {
      await bookmarkService.processBookmarkSyncQueue();
      final updatedBookmarks = await bookmarkService.getUserBookmarks();
      yield updatedBookmarks;
    } catch (e) {
      yield initialBookmarks;
    }
  }
});

// Provider for bookmark operations with sync tracking
class BookmarkOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final BookmarkService _bookmarkService;
  final SyncQueueProcessor _syncQueueProcessor;

  BookmarkOperationsNotifier(this._bookmarkService, this._syncQueueProcessor)
      : super(const AsyncValue.data(null));

  Future<void> addBookmark(BookmarkModel bookmark) async {
    state = const AsyncValue.loading();
    try {
      await _bookmarkService.addBookmark(
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
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: bookmark.toJson(),
      );
    }
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    state = const AsyncValue.loading();
    try {
      await _bookmarkService.deleteBookmark(bookmarkId);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: {
          'id': bookmarkId,
          'operation': 'delete',
        },
      );
    }
  }

  Future<void> updateBookmark(BookmarkModel bookmark) async {
    state = const AsyncValue.loading();
    try {
      await _bookmarkService.updateBookmark(
        id: bookmark.id,
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
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      await _syncQueueProcessor.addToQueue(
        type: SyncOperationType.bookmark,
        data: bookmark.toJson(),
      );
    }
  }
}

// Provider for bookmark operations
final bookmarkOperationsProvider =
    StateNotifierProvider<BookmarkOperationsNotifier, AsyncValue<void>>((ref) {
  final bookmarkService = ref.watch(bookmarkServiceProvider);
  final syncQueueProcessor = ref.watch(syncQueueProcessorProvider);
  return BookmarkOperationsNotifier(bookmarkService, syncQueueProcessor);
});

// Widget to show sync status for bookmarks
class BookmarkSyncStatusWidget extends ConsumerWidget {
  const BookmarkSyncStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncQueueStatusProvider);

    return syncStatus.when(
      data: (items) {
        final bookmarkSyncItems = items
            .where(
                (item) => item['type'] == SyncOperationType.bookmark.toString())
            .toList();

        if (bookmarkSyncItems.isEmpty) return const SizedBox.shrink();

        return Container(
          color: Colors.orange[100],
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.sync, color: Colors.orange),
              const SizedBox(width: 8),
              Text('${bookmarkSyncItems.length} bookmark sync items pending'),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Container(
        color: Colors.red[100],
        padding: const EdgeInsets.all(8),
        child: Text('Bookmark Sync Error: $error'),
      ),
    );
  }
}
