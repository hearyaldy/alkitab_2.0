// lib/services/sync_queue_processor.dart

import 'package:flutter/foundation.dart'; // ✅ for debugPrint
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alkitab_2_0/services/firebase_service.dart';

enum SyncOperationType {
  bookmark,
  highlight,
  settings,
  note,
}

class SyncQueueProcessor {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> processQueue() async {
    final syncQueueBox = await Hive.openBox('sync_queue');
    final syncItems = syncQueueBox.toMap().entries.toList();

    for (var entry in syncItems) {
      final key = entry.key;
      final item = entry.value;

      try {
        if (item is Map<String, dynamic>) {
          final type = item['type'];
          final data = item['data'];

          if (type == SyncOperationType.bookmark.name) {
            await _processBookmarkSync(data);
          } else if (type == SyncOperationType.settings.name) {
            await _processSettingsSync(data);
          }

          await syncQueueBox.delete(key);
        }
      } catch (e) {
        debugPrint('Error processing sync queue item: $e');
      }
    }
  }

  Future<void> _processBookmarkSync(Map<String, dynamic> bookmarkData) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      // Convert user.id to user.uid for Firebase
      if (bookmarkData['user_id'] != null) {
        bookmarkData['user_id'] = user.uid;
      }

      // Add or update the bookmark in Firestore
      final docId = bookmarkData['id'] ?? _firestore.collection('user_bookmarks').doc().id;
      await _firestore.collection('user_bookmarks').doc(docId).set(
        bookmarkData,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Bookmark sync error during processing: $e');
    }
  }

  Future<void> _processSettingsSync(Map<String, dynamic> settingsData) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      // Convert user.id to user.uid for Firebase
      if (settingsData['user_id'] != null) {
        settingsData['user_id'] = user.uid;
      }

      // Add or update the settings in Firestore
      final docId = settingsData['id'] ?? _firestore.collection('user_settings').doc().id;
      await _firestore.collection('user_settings').doc(docId).set(
        settingsData,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Settings sync error during processing: $e');
    }
  }

  Future<void> addToQueue({
    required SyncOperationType type,
    required Map<String, dynamic> data,
  }) async {
    final syncQueueBox = await Hive.openBox('sync_queue');
    await syncQueueBox.add({
      'type': type.name,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
