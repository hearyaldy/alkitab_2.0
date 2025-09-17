// lib/services/highlight_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/firebase_service.dart';

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

    // Try to sync with Firebase if user is logged in
    _syncHighlightWithFirebase(highlight);

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

    // Try to remove from Firebase
    _removeHighlightFromFirebase(highlight);
  }

  // Sync all local highlights with Firebase
  static Future<void> syncAllHighlights() async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user == null) return;

    try {
      // Get all local highlights
      final localHighlights = await getAllHighlights();

      // Get all remote highlights from Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_highlights')
          .where('user_id', isEqualTo: user.uid)
          .where('type', isEqualTo: 'bible')
          .get();

      // Process remote highlights
      final remoteHighlights = <HighlightModel>[];
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final bookId = data['book_id'] as String;
          final chapterId = data['chapter_id'] as int;
          final verseNumber = data['verse_id'] as int;
          final colorHex =
              data['color_hex'] as String? ?? HighlightColors.yellow;
          final note = data['note'] as String?;
          final createdAt = (data['created_at'] as Timestamp).toDate();
          final id = doc.id;

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

  // Private method to sync a highlight with Firebase
  static Future<void> _syncHighlightWithFirebase(
      HighlightModel highlight) async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user == null) return;

    try {
      // Check if the highlight exists remotely
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_highlights')
          .where('user_id', isEqualTo: user.uid)
          .where('book_id', isEqualTo: highlight.bookId)
          .where('chapter_id', isEqualTo: highlight.chapterId)
          .where('verse_id', isEqualTo: highlight.verseNumber)
          .get();

      final bookName = getBookNameById(highlight.bookId);
      final verseReference =
          '$bookName ${highlight.chapterId}:${highlight.verseNumber}';

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing highlight
        final docId = querySnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('user_highlights')
            .doc(docId)
            .update({
          'color_hex': highlight.colorHex,
          'note': highlight.note,
          'updated_at': Timestamp.now(),
        });
      } else {
        // Create new highlight
        await FirebaseFirestore.instance.collection('user_highlights').add({
          'user_id': user.uid,
          'book_id': highlight.bookId,
          'chapter_id': highlight.chapterId,
          'verse_id': highlight.verseNumber,
          'verse_reference': verseReference,
          'color_hex': highlight.colorHex,
          'note': highlight.note,
          'type': 'bible',
          'created_at': Timestamp.fromDate(highlight.createdAt),
        });
      }
    } catch (e) {
      debugPrint('Error syncing highlight with Firebase: $e');
    }
  }

  // Private method to remove a highlight from Firebase
  static Future<void> _removeHighlightFromFirebase(
      HighlightModel highlight) async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_highlights')
          .where('user_id', isEqualTo: user.uid)
          .where('book_id', isEqualTo: highlight.bookId)
          .where('chapter_id', isEqualTo: highlight.chapterId)
          .where('verse_id', isEqualTo: highlight.verseNumber)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error removing highlight from Firebase: $e');
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
