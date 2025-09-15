import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // For debugging
import '../services/bible_service.dart';
import '../models/bible_model.dart';

class OfflineBibleProvider extends StateNotifier<List<BibleVerse>> {
  final BibleService _bibleService;

  OfflineBibleProvider(this._bibleService) : super([]);

  Future<void> fetchVerses({
    required String bookId,
    required int chapterId,
    String version = 'ABB',
  }) async {
    try {
      // Use the instance method correctly
      final verses = await _bibleService.fetchVerses(bookId, chapterId);
      state = verses;
    } catch (e) {
      state = [];
      // Use debugPrint for debug-only logging
      debugPrint('Error fetching verses: $e');
    }
  }
}

// Provider for easy access
final offlineBibleProvider =
    StateNotifierProvider<OfflineBibleProvider, List<BibleVerse>>((ref) {
  return OfflineBibleProvider(BibleService());
});
