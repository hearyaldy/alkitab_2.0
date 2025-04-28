import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _connectivity = Connectivity();

  // Check if sync is possible (maintaining original method)
  Future<bool> canSync() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  // Enhanced bookmarks sync method
  Future<void> syncBookmarks() async {
    try {
      if (!await canSync()) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localBookmarks = prefs.getStringList('bookmarks') ?? [];

      // Open Hive box for sync queue
      final syncQueueBox = await Hive.openBox('sync_queue');

      for (var bookmark in localBookmarks) {
        try {
          // Parse bookmark and prepare for Supabase
          final bookmarkData = _parseBookmark(bookmark);

          // Upsert bookmark to Supabase
          final response = await _supabase
              .from('user_bookmarks')
              .upsert(bookmarkData)
              .select();

          // If successful, you might want to remove from local queue
          if (response.isNotEmpty) {
            syncQueueBox.delete(bookmark);
          }
        } catch (e) {
          // If sync fails, add to sync queue
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

  // Helper method to parse bookmark (customize based on your bookmark structure)
  Map<String, dynamic> _parseBookmark(String bookmarkString) {
    // Implement your bookmark parsing logic
    // This is a placeholder - modify to match your actual bookmark structure
    return {
      'bookmark_data': bookmarkString,
      // Add other necessary fields
    };
  }

  // Sync user settings (enhanced with more robust error handling)
  Future<void> syncUserSettings() async {
    try {
      if (!await canSync()) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Example settings to sync
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

  // Periodic sync method with more comprehensive approach
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

  // New method to sync reading progress
  Future<void> _syncReadingProgress() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final lastReadings = prefs.getStringList('last_readings');

      if (lastReadings != null && lastReadings.isNotEmpty) {
        // Sync the most recent reading
        final mostRecentReading = lastReadings.first;
        // Parse and sync reading progress
        await _supabase.from('reading_progress').upsert({
          'user_id': user.id,
          'reading_data': mostRecentReading,
        });
      }
    } catch (e) {
      print('Reading progress sync error: $e');
    }
  }

  // Start background sync service
  void startBackgroundSync() {
    // Periodic sync every 30 minutes
    Timer.periodic(Duration(minutes: 30), (_) {
      performPeriodicSync();
    });
  }
}
