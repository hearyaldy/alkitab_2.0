// lib/providers/highlight_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/highlight_model.dart';
import '../services/highlight_service.dart';
import '../services/sync_queue_processor.dart';
import '../providers/sync_providers.dart';

// Provider for HighlightService
final highlightServiceProvider = Provider<HighlightService>((ref) {
  final syncQueueProcessor = ref.watch(syncQueueProcessorProvider);
  return HighlightService(syncQueueProcessor);
});

// Provider for all highlights (with loading, error states)
final highlightsProvider = FutureProvider<List<HighlightModel>>((ref) async {
  final highlightService = ref.watch(highlightServiceProvider);
  return highlightService.getUserHighlights();
});

// Provider for highlights in a specific chapter
final chapterHighlightsProvider = FutureProvider.family<List<HighlightModel>,
    ({String bookId, int chapterId})>(
  (ref, params) async {
    final highlightService = ref.watch(highlightServiceProvider);
    return highlightService.getHighlightsForChapter(
      bookId: params.bookId,
      chapterId: params.chapterId,
    );
  },
);

// Provider for a specific verse's highlight color
final verseHighlightColorProvider = FutureProvider.family<String?,
    ({String bookId, int chapterId, int verseId})>(
  (ref, params) async {
    final highlightService = ref.watch(highlightServiceProvider);
    return highlightService.getHighlightColorForVerse(
      bookId: params.bookId,
      chapterId: params.chapterId,
      verseId: params.verseId,
    );
  },
);

// A provider for highlight operations with loading states
class HighlightOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final HighlightService _highlightService;

  HighlightOperationsNotifier(this._highlightService)
      : super(const AsyncValue.data(null));

  Future<void> addHighlight({
    required String bookId,
    required int chapterId,
    required int verseId,
    required String colorCode,
    String? verseText,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _highlightService.addHighlight(
        bookId: bookId,
        chapterId: chapterId,
        verseId: verseId,
        colorCode: colorCode,
        verseText: verseText,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> deleteHighlight(String highlightId) async {
    state = const AsyncValue.loading();
    try {
      await _highlightService.deleteHighlight(highlightId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateHighlight({
    required String id,
    required String colorCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _highlightService.updateHighlight(
        id: id,
        colorCode: colorCode,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refreshHighlights() async {
    state = const AsyncValue.loading();
    try {
      await _highlightService.processHighlightSyncQueue();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Provider for highlight operations
final highlightOperationsProvider =
    StateNotifierProvider<HighlightOperationsNotifier, AsyncValue<void>>((ref) {
  final highlightService = ref.watch(highlightServiceProvider);
  return HighlightOperationsNotifier(highlightService);
});

// Helper to check if a verse is highlighted in current state
final isVerseHighlightedProvider =
    Provider.family<bool, ({String bookId, int chapterId, int verseId})>(
  (ref, params) {
    final highlights = ref.watch(highlightsProvider);

    return highlights.maybeWhen(
      data: (data) => data.any((highlight) =>
          highlight.bookId == params.bookId &&
          highlight.chapterId == params.chapterId &&
          highlight.verseId == params.verseId),
      orElse: () => false,
    );
  },
);

// Available highlight colors provider
final highlightColorsProvider = Provider<List<HighlightColor>>((ref) {
  return [
    HighlightColor(code: '#FFEB3B', name: 'Yellow'),
    HighlightColor(code: '#4CAF50', name: 'Green'),
    HighlightColor(code: '#2196F3', name: 'Blue'),
    HighlightColor(code: '#F44336', name: 'Red'),
    HighlightColor(code: '#9C27B0', name: 'Purple'),
    HighlightColor(code: '#FF9800', name: 'Orange'),
  ];
});

// Highlight color model for UI
class HighlightColor {
  final String code;
  final String name;

  const HighlightColor({
    required this.code,
    required this.name,
  });
}
