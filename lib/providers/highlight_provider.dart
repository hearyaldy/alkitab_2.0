// lib/providers/highlight_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/services/highlight_service.dart';

// All highlights
final highlightListProvider = FutureProvider<List<HighlightModel>>((ref) async {
  return await HighlightService.getAllHighlights();
});

// Highlights for specific chapter
final chapterHighlightsProvider =
    FutureProvider.family<List<HighlightModel>, (String, int)>(
        (ref, tuple) async {
  final (bookId, chapterId) = tuple;
  return await HighlightService.getChapterHighlights(bookId, chapterId);
});

// Specific verse highlight color
final verseHighlightProvider =
    FutureProvider.family<HighlightModel?, (String, int, int)>(
        (ref, tuple) async {
  final (bookId, chapterId, verseNumber) = tuple;
  return await HighlightService.getVerseHighlight(
      bookId, chapterId, verseNumber);
});

// A simpler provider that just returns the color as a string
final highlightColorProvider =
    FutureProvider.family<String?, (String, int, int)>((ref, tuple) async {
  final (bookId, chapterId, verseNumber) = tuple;
  final highlight =
      await HighlightService.getVerseHighlight(bookId, chapterId, verseNumber);
  return highlight?.colorHex;
});

// Create a StateProvider to trigger refreshes
final highlightRefreshProvider = StateProvider<int>((ref) => 0);

// Helper function to add a highlight
Future<void> addHighlight(
  WidgetRef ref, {
  required String bookId,
  required int chapterId,
  required int verseNumber,
  required String colorHex,
  String? verseText,
}) async {
  await HighlightService.addHighlight(
    bookId: bookId,
    chapterId: chapterId,
    verseNumber: verseNumber,
    colorHex: colorHex,
    note: verseText,
  );

  // Increment refresh counter to trigger UI updates
  ref.read(highlightRefreshProvider.notifier).state++;

  // Invalidate related providers
  ref.invalidate(highlightListProvider);
  ref.invalidate(chapterHighlightsProvider((bookId, chapterId)));
  ref.invalidate(verseHighlightProvider((bookId, chapterId, verseNumber)));
  ref.invalidate(highlightColorProvider((bookId, chapterId, verseNumber)));
}

// Helper function to remove a highlight
Future<void> removeHighlight(
  WidgetRef ref, {
  required String bookId,
  required int chapterId,
  required int verseNumber,
}) async {
  await HighlightService.removeHighlight(bookId, chapterId, verseNumber);

  // Increment refresh counter to trigger UI updates
  ref.read(highlightRefreshProvider.notifier).state++;

  // Invalidate related providers
  ref.invalidate(highlightListProvider);
  ref.invalidate(chapterHighlightsProvider((bookId, chapterId)));
  ref.invalidate(verseHighlightProvider((bookId, chapterId, verseNumber)));
  ref.invalidate(highlightColorProvider((bookId, chapterId, verseNumber)));
}

// Sync all highlights with Supabase
final syncHighlightProvider = FutureProvider<void>((ref) async {
  await HighlightService.syncAllHighlights();

  // Increment refresh counter to trigger UI updates
  ref.read(highlightRefreshProvider.notifier).state++;

  // Invalidate all highlight providers
  ref.invalidate(highlightListProvider);
});
