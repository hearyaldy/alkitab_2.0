// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _connectivity = Connectivity();

  Future<bool> canSync() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<void> syncBookmarks() async {
    try {
      if (!await canSync()) return;

      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localBookmarks = prefs.getStringList('bookmarks') ?? [];

      final syncQueueBox = await Hive.openBox('sync_queue');

      for (var bookmark in localBookmarks) {
        try {
          final bookmarkData = _parseBookmark(bookmark);
          bookmarkData['user_id'] = user.uid;
          bookmarkData['created_at'] = FieldValue.serverTimestamp();

          // Check if bookmark already exists
          final query = await _firestore
              .collection('bookmarks')
              .where('user_id', isEqualTo: user.uid)
              .where('bookmark_data', isEqualTo: bookmark)
              .limit(1)
              .get();

          if (query.docs.isEmpty) {
            // Create new bookmark
            await _firestore.collection('bookmarks').add(bookmarkData);
          } else {
            // Update existing bookmark
            await query.docs.first.reference.update(bookmarkData);
          }

          syncQueueBox.delete(bookmark);
        } catch (e) {
          await syncQueueBox.put(bookmark, {
            'type': 'bookmark',
            'data': bookmark,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('Individual bookmark sync error: $e');
        }
      }
    } catch (e) {
      print('Bookmark sync error: $e');
    }
  }

  Map<String, dynamic> _parseBookmark(String bookmarkString) {
    return {
      'bookmark_data': bookmarkString,
      'type': 'bible',
      'sync_timestamp': FieldValue.serverTimestamp(),
    };
  }

  Future<void> syncUserSettings() async {
    try {
      if (!await canSync()) return;

      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      final darkMode = prefs.getBool('darkMode') ?? false;
      final fontSize = prefs.getDouble('fontSize') ?? 16.0;
      final preferredBibleVersion =
          prefs.getString('preferredBibleVersion') ?? 'ABB';

      final settingsData = {
        'user_id': user.uid,
        'dark_mode': darkMode,
        'font_size': fontSize,
        'preferred_bible_version': preferredBibleVersion,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Use set with merge to update or create settings document
      await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .set(settingsData, SetOptions(merge: true));
    } catch (e) {
      print('Settings sync error: $e');
    }
  }

  Future<void> performPeriodicSync() async {
    if (!await canSync()) return;

    try {
      await Future.wait([
        syncBookmarks(),
        syncUserSettings(),
        _syncReadingProgress(),
      ]);
    } catch (e) {
      print('Periodic sync error: $e');
    }
  }

  Future<void> _syncReadingProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final lastReadings = prefs.getStringList('last_readings');

      if (lastReadings != null && lastReadings.isNotEmpty) {
        final mostRecentReading = lastReadings.first;

        await _firestore.collection('reading_progress').add({
          'user_id': user.uid,
          'reading_data': mostRecentReading,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Keep only the last 100 reading progress entries
        final oldEntries = await _firestore
            .collection('reading_progress')
            .where('user_id', isEqualTo: user.uid)
            .orderBy('created_at', descending: true)
            .limit(101)
            .get();

        if (oldEntries.docs.length > 100) {
          final lastDoc = oldEntries.docs.last;
          await lastDoc.reference.delete();
        }
      }
    } catch (e) {
      print('Reading progress sync error: $e');
    }
  }

  // Listen for remote changes and update local storage
  Stream<void> watchRemoteChanges() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('user_settings')
        .doc(user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final prefs = await SharedPreferences.getInstance();

      // Update local settings
      if (data['dark_mode'] != null) {
        await prefs.setBool('darkMode', data['dark_mode']);
      }
      if (data['font_size'] != null) {
        await prefs.setDouble('fontSize', data['font_size'].toDouble());
      }
      if (data['preferred_bible_version'] != null) {
        await prefs.setString(
            'preferredBibleVersion', data['preferred_bible_version']);
      }
    });
  }

  void startBackgroundSync() {
    // Start periodic sync
    Timer.periodic(const Duration(minutes: 30), (_) {
      performPeriodicSync();
    });

    // Start watching for remote changes
    watchRemoteChanges();
  }
}
