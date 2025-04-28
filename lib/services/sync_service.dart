// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  SupabaseClient get _supabase => Supabase.instance.client;
  final _connectivity = Connectivity();

  Future<bool> canSync() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  Future<void> syncBookmarks() async {
    try {
      if (!await canSync()) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localBookmarks = prefs.getStringList('bookmarks') ?? [];

      final syncQueueBox = await Hive.openBox('sync_queue');

      for (var bookmark in localBookmarks) {
        try {
          final bookmarkData = _parseBookmark(bookmark);

          final response = await _supabase
              .from('user_bookmarks')
              .upsert(bookmarkData)
              .select();

          if (response.isNotEmpty) {
            syncQueueBox.delete(bookmark);
          }
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
    };
  }

  Future<void> syncUserSettings() async {
    try {
      if (!await canSync()) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      final darkMode = prefs.getBool('darkMode') ?? false;
      final fontSize = prefs.getDouble('fontSize') ?? 16.0;
      final preferredBibleVersion =
          prefs.getString('preferredBibleVersion') ?? 'ABB';

      final settingsData = {
        'user_id': user.id,
        'dark_mode': darkMode,
        'font_size': fontSize,
        'preferred_bible_version': preferredBibleVersion,
      };

      await _supabase.from('user_settings').upsert(settingsData);
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
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final lastReadings = prefs.getStringList('last_readings');

      if (lastReadings != null && lastReadings.isNotEmpty) {
        final mostRecentReading = lastReadings.first;
        await _supabase.from('reading_progress').upsert({
          'user_id': user.id,
          'reading_data': mostRecentReading,
        });
      }
    } catch (e) {
      print('Reading progress sync error: $e');
    }
  }

  void startBackgroundSync() {
    Timer.periodic(const Duration(minutes: 30), (_) {
      performPeriodicSync();
    });
  }
}
