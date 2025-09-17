import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/mock_data_service.dart';

class FirebaseDataMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main migration function - transfers devotional data to Firebase
  /// (Bible data remains in local JSON files)
  static Future<void> migrateAllData() async {
    debugPrint('🔄 Starting Firebase devotional migration...');

    try {
      // Initialize mock data first
      await MockDataService.initialize();

      // Only migrate devotionals - Bible data stays local
      await migrateDevotionals();

      debugPrint('✅ Firebase devotional migration completed successfully!');
    } catch (e) {
      debugPrint('❌ Firebase devotional migration failed: $e');
      rethrow;
    }
  }

  /// Migrate Bible versions to Firestore
  static Future<void> migrateBibleVersions() async {
    debugPrint('📖 Migrating Bible versions...');

    final versions = MockDataService.getVersions();
    final batch = _firestore.batch();

    for (final version in versions) {
      final docRef = _firestore.collection('bible_versions').doc(version.id);
      batch.set(docRef, {
        'id': version.id,
        'name': version.name,
        'code': version.code,
        'description': version.description,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ Migrated ${versions.length} Bible versions');
  }

  /// Migrate Bible books to Firestore
  static Future<void> migrateBibleBooks() async {
    debugPrint('📚 Migrating Bible books...');

    final books = MockDataService.getBooks();
    final batch = _firestore.batch();

    for (final book in books) {
      final docRef = _firestore.collection('bible_books').doc(book.id);
      batch.set(docRef, {
        'id': book.id,
        'name': book.name,
        'abbreviation': book.abbreviation,
        'order': book.order,
        'testament': book.testament,
        'chapters': book.chapters,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ Migrated ${books.length} Bible books');
  }

  /// Migrate Bible verses to Firestore (in batches for performance)
  static Future<void> migrateBibleVerses() async {
    debugPrint('📜 Migrating Bible verses...');

    // Get all verses for all books and chapters
    final books = MockDataService.getBooks();
    int totalMigrated = 0;

    for (final book in books) {
      for (int chapter = 1; chapter <= book.chapters; chapter++) {
        final verses = MockDataService.getVerses(bookId: book.id, chapter: chapter);
        if (verses.isEmpty) continue;

        final batch = _firestore.batch();

        for (final verse in verses) {
          final docRef = _firestore.collection('bible_verses').doc();
          batch.set(docRef, {
            'book_id': verse.bookId,
            'chapter_id': verse.chapterId,
            'verse_number': verse.verseNumber,
            'text': verse.text,
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        totalMigrated += verses.length;
        debugPrint('📊 Migrated ${verses.length} verses from ${book.name} chapter $chapter (Total: $totalMigrated)');
      }
    }

    debugPrint('✅ Migrated $totalMigrated Bible verses');
  }

  /// Migrate devotionals to Firestore
  static Future<void> migrateDevotionals() async {
    debugPrint('🙏 Migrating devotionals...');

    final devotionals = MockDataService.getDevotionals();
    final batch = _firestore.batch();

    for (final devotional in devotionals) {
      final docRef = _firestore.collection('devotionals').doc(devotional.id);
      batch.set(docRef, {
        'id': devotional.id,
        'title': devotional.title,
        'verse_reference': devotional.verseReference,
        'verse_text': devotional.verseText,
        'content': devotional.content,
        'reflection_questions': devotional.reflectionQuestions,
        'prayer': devotional.prayer,
        'date': Timestamp.fromDate(devotional.date),
        'author': devotional.author,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ Migrated ${devotionals.length} devotionals');
  }

  /// Check if devotional data already exists in Firestore
  static Future<bool> isDataAlreadyMigrated() async {
    try {
      final devotionalsSnapshot = await _firestore.collection('devotionals').limit(1).get();
      return devotionalsSnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return false;
    }
  }

  /// Clean devotional data (useful for testing)
  static Future<void> cleanAllData() async {
    debugPrint('🧹 Cleaning devotional data...');

    try {
      // Only delete devotionals collection
      await _deleteCollection('devotionals');

      debugPrint('✅ Devotional data cleaned');
    } catch (e) {
      debugPrint('❌ Error cleaning data: $e');
      rethrow;
    }
  }

  /// Helper method to delete all documents in a collection
  static Future<void> _deleteCollection(String collectionName) async {
    final snapshot = await _firestore.collection(collectionName).get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    debugPrint('🗑️ Deleted ${snapshot.docs.length} documents from $collectionName');
  }

  /// Get devotional migration statistics
  static Future<Map<String, int>> getMigrationStats() async {
    try {
      final stats = <String, int>{};

      final devotionalsSnapshot = await _firestore.collection('devotionals').get();
      stats['devotionals'] = devotionalsSnapshot.docs.length;

      return stats;
    } catch (e) {
      debugPrint('Error getting migration stats: $e');
      return {};
    }
  }
}