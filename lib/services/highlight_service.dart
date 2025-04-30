// lib/services/highlight_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';

class HighlightService {
  // Hive box name
  static const String _boxName = 'bible_highlights';

  // Get all highlights for the current user
  static Future<List<HighlightModel>> getAllHighlights() async {
    final box = await Hive.openBox<Map>(_boxName);
    return box.values
        .map((e) => HighlightModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // Get highlights for a specific chapter
  static Future<List<HighlightModel>> getChapterHighlights(
    String bookId,
    int chapterId,
  ) async {
    final box = await Hive.openBox<Map>(_boxName);

    return box.values
        .map((e) => HighlightModel.fromJson(Map<String, dynamic>.from(e)))
        .where((h) => h.bookId == bookId && h.chapterId == chapterId)
        .toList();
  }

  // Get highlight for a specific verse (if exists)
  static Future<HighlightModel?> getVerseHighlight(
    String bookId,
    int chapterId,
    int verseNumber,
  ) async {
    final box = await Hive.openBox<Map>(_boxName);

    final matches = box.values
        .map((e) => HighlightModel.fromJson(Map<String, dynamic>.from(e)))
        .where((h) =>
            h.bookId == bookId &&
            h.chapterId == chapterId &&
            h.verseNumber == verseNumber)
        .toList();

    return matches.isNotEmpty ? matches.first : null;
  }

  // Add or update a highlight
  static Future<HighlightModel> addHighlight({
    required String bookId,
    required int chapterId,
    required int verseNumber,
    required String colorHex,
    String? note,
  }) async {
    final box = await Hive.openBox<Map>(_boxName);

    // Check if highlight already exists
    final existing = await getVerseHighlight(bookId, chapterId, verseNumber);

    // Create a new highlight or update existing one
    final highlight = existing != null
        ? HighlightModel(
            id: existing.id,
            bookId: bookId,
            chapterId: chapterId,
            verseNumber: verseNumber,
            colorHex: colorHex,
            createdAt: existing.createdAt,
            note: note ?? existing.note,
          )
        : HighlightModel.create(
            bookId: bookId,
            chapterId: chapterId,
            verseNumber: verseNumber,
            colorHex: colorHex,
            note: note,
          );

    // Save to Hive
    await box.put(highlight.id, highlight.toJson());

    // Try to sync with Supabase if user is logged in
    _syncHighlightWithSupabase(highlight);

    return highlight;
  }

  // Remove a highlight
  static Future<void> removeHighlight(
    String bookId,
    int chapterId,
    int verseNumber,
  ) async {
    final box = await Hive.openBox<Map>(_boxName);

    // Find the highlight to remove
    final highlight = await getVerseHighlight(bookId, chapterId, verseNumber);
    if (highlight == null) return;

    // Remove from Hive
    await box.delete(highlight.id);

    // Try to remove from Supabase
    _removeHighlightFromSupabase(highlight);
  }

  // Sync all local highlights with Supabase
  static Future<void> syncAllHighlights() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Get all local highlights
      final localHighlights = await getAllHighlights();

      // Get all remote highlights
      final response = await Supabase.instance.client
          .from('user_highlights')
          .select()
          .eq('user_id', user.id)
          .eq('type', 'bible');

      // Process remote highlights
      final remoteHighlights = <HighlightModel>[];
      for (final item in response) {
        try {
          final bookId = item['book_id'] as String;
          final chapterId = item['chapter_id'] as int;
          final verseNumber = item['verse_id'] as int;
          final colorHex =
              item['color_hex'] as String? ?? HighlightColors.yellow;
          final note = item['note'] as String?;
          final createdAt = DateTime.parse(item['created_at']);
          final id = item['id'] as String;

          remoteHighlights.add(HighlightModel(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            verseNumber: verseNumber,
            colorHex: colorHex,
            createdAt: createdAt,
            note: note,
          ));
        } catch (e) {
          debugPrint('Error parsing remote highlight: $e');
        }
      }

      // Merge local and remote
      await _mergeHighlights(localHighlights, remoteHighlights);
    } catch (e) {
      debugPrint('Error syncing highlights: $e');
    }
  }

  // Private method to sync a highlight with Supabase
  static Future<void> _syncHighlightWithSupabase(
      HighlightModel highlight) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Check if the highlight exists remotely
      final response = await Supabase.instance.client
          .from('user_highlights')
          .select('id')
          .eq('user_id', user.id)
          .eq('book_id', highlight.bookId)
          .eq('chapter_id', highlight.chapterId)
          .eq('verse_id', highlight.verseNumber)
          .maybeSingle();

      final bookName = getBookName(highlight.bookId);
      final verseReference =
          '$bookName ${highlight.chapterId}:${highlight.verseNumber}';

      if (response != null) {
        // Update existing highlight
        await Supabase.instance.client.from('user_highlights').update({
          'color_hex': highlight.colorHex,
          'note': highlight.note,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', response['id']);
      } else {
        // Create new highlight
        await Supabase.instance.client.from('user_highlights').insert({
          'user_id': user.id,
          'book_id': highlight.bookId,
          'chapter_id': highlight.chapterId,
          'verse_id': highlight.verseNumber,
          'verse_reference': verseReference,
          'color_hex': highlight.colorHex,
          'note': highlight.note,
          'type': 'bible',
          'created_at': highlight.createdAt.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error syncing highlight with Supabase: $e');
    }
  }

  // Private method to remove a highlight from Supabase
  static Future<void> _removeHighlightFromSupabase(
      HighlightModel highlight) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('user_highlights')
          .delete()
          .eq('user_id', user.id)
          .eq('book_id', highlight.bookId)
          .eq('chapter_id', highlight.chapterId)
          .eq('verse_id', highlight.verseNumber);
    } catch (e) {
      debugPrint('Error removing highlight from Supabase: $e');
    }
  }

  // Merge local and remote highlights
  static Future<void> _mergeHighlights(
    List<HighlightModel> localHighlights,
    List<HighlightModel> remoteHighlights,
  ) async {
    final box = await Hive.openBox<Map>(_boxName);

    // Map for easy lookup
    final Map<String, HighlightModel> localByKey = {};
    final Map<String, HighlightModel> remoteByKey = {};

    for (final h in localHighlights) {
      final key = '${h.bookId}_${h.chapterId}_${h.verseNumber}';
      localByKey[key] = h;
    }

    for (final h in remoteHighlights) {
      final key = '${h.bookId}_${h.chapterId}_${h.verseNumber}';
      remoteByKey[key] = h;
    }

    // Process all keys
    final allKeys = <String>{...localByKey.keys, ...remoteByKey.keys};

    for (final key in allKeys) {
      final local = localByKey[key];
      final remote = remoteByKey[key];

      if (local != null && remote != null) {
        // Both exist - use newer one
        final useRemote = remote.createdAt.isAfter(local.createdAt);
        if (useRemote) {
          await box.put(remote.id, remote.toJson());
        }
      } else if (remote != null) {
        // Only remote exists - add to local
        await box.put(remote.id, remote.toJson());
      }
      // If only local exists, keep it as is
    }
  }
}
