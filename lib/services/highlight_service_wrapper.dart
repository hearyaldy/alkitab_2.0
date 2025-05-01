// lib/services/highlight_service_wrapper.dart

import 'package:alkitab_2_0/services/highlight_service.dart';

// This wrapper class isolates the HighlightService calls to avoid
// any potential naming conflicts or dependency issues
class HighlightServiceWrapper {
  static Future<void> addVerseHighlight({
    required String bookId,
    required int chapterId,
    required int verseNumber,
    required String colorHex,
    String? note,
  }) async {
    try {
      await HighlightService.addHighlight(
        bookId: bookId,
        chapterId: chapterId,
        verseNumber: verseNumber,
        colorHex: colorHex,
        note: note,
      );
    } catch (e) {
      print('Error adding highlight: $e');
    }
  }

  static Future<void> removeVerseHighlight({
    required String bookId,
    required int chapterId,
    required int verseNumber,
  }) async {
    try {
      await HighlightService.removeHighlight(
        bookId,
        chapterId,
        verseNumber,
      );
    } catch (e) {
      print('Error removing highlight: $e');
    }
  }
}