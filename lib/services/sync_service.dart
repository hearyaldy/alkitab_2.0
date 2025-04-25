import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _connectivity = Connectivity();

  // Check if sync is possible
  Future<bool> canSync() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  // Sync bookmarks
  Future<void> syncBookmarks() async {
    try {
      if (!await canSync()) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localBookmarks = prefs.getStringList('bookmarks') ?? [];

      // Sync local bookmarks with Supabase
      for (var bookmark in localBookmarks) {
        // Parse bookmark and insert/update in Supabase
        // You'll need to implement the specific logic based on your bookmark structure
      }
    } catch (e) {
      print('Bookmark sync error: $e');
    }
  }

  // Sync user settings
  Future<void> syncUserSettings() async {
    try {
      if (!await canSync()) return;

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      // Example settings to sync
      final darkMode = prefs.getBool('darkMode') ?? false;
      final fontSize = prefs.getDouble('fontSize') ?? 16.0;

      await _supabase.from('user_settings').upsert({
        'user_id': user.id,
        'dark_mode': darkMode,
        'font_size': fontSize,
      });
    } catch (e) {
      print('Settings sync error: $e');
    }
  }

  // Periodic sync method
  Future<void> performPeriodicSync() async {
    if (!await canSync()) return;

    await syncBookmarks();
    await syncUserSettings();
  }
}
