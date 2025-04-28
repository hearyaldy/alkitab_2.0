import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';
import 'sync_service.dart';
import '../config/constants.dart';

class AuthService {
  // Static instance of SyncService for offline sync capabilities
  static final _syncService = SyncService();

  // Sign up with email and password
  static Future<User?> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
        },
      );

      if (response.user != null) {
        // Save user to local storage
        final userBox = await Hive.openBox(AppConstants.userBoxName);
        await userBox.put('currentUser', response.user!.toJson());

        // Save additional profile info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        if (displayName != null) {
          await prefs.setString('user_display_name', displayName);
        }

        // Attempt to sync user data if online
        await _syncService.performPeriodicSync();
      }

      return response.user;
    } catch (e) {
      debugPrint('Sign up error: $e');

      // Store signup attempt for later sync if offline
      await LocalStorageService.addToSyncQueue('signup', {
        'email': email,
        'display_name': displayName,
      });

      rethrow;
    }
  }

  // Sign in with email and password
  static Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Save user to local storage
        final userBox = await Hive.openBox(AppConstants.userBoxName);
        await userBox.put('currentUser', response.user!.toJson());

        // Save to shared preferences for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setBool('is_logged_in', true);

        // Attempt to sync user data
        await _syncService.performPeriodicSync();
      }

      return response.user;
    } catch (e) {
      debugPrint('Sign in error: $e');

      // Store login attempt for potential offline retry
      await LocalStorageService.addToSyncQueue('login', {
        'email': email,
      });

      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await SupabaseService.auth.signOut();

      // Clear user from local storage
      final userBox = await Hive.openBox(AppConstants.userBoxName);
      await userBox.delete('currentUser');

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('is_logged_in');
      await prefs.remove('user_display_name');
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await SupabaseService.auth.resetPasswordForEmail(email);

      // Store reset attempt in case of offline scenario
      await LocalStorageService.addToSyncQueue('password_reset', {
        'email': email,
      });
    } catch (e) {
      debugPrint('Reset password error: $e');
      rethrow;
    }
  }

  // Get current user from local storage (for offline mode)
  static Future<Map<String, dynamic>?> getCurrentUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!isLoggedIn) return null;

    final userBox = await Hive.openBox(AppConstants.userBoxName);
    return userBox.get('currentUser');
  }

  // Check if user is authenticated (either online or from local storage)
  static Future<bool> isAuthenticated() async {
    // Check Supabase authentication first
    if (SupabaseService.isAuthenticated) return true;

    // Check local storage
    final user = await getCurrentUserFromStorage();
    return user != null;
  }

  // Update user profile
  static Future<void> updateProfile({
    String? displayName,
    String? email,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Prepare update data
      final updateData = <String, dynamic>{};
      if (displayName != null) updateData['display_name'] = displayName;
      if (email != null) updateData['email'] = email;

      // Update Supabase user
      await SupabaseService.auth.updateUser(
        UserAttributes(
          email: email,
          data: updateData,
        ),
      );

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null) {
        await prefs.setString('user_display_name', displayName);
      }
      if (email != null) {
        await prefs.setString('user_email', email);
      }

      // Store profile update in sync queue for potential offline sync
      await LocalStorageService.addToSyncQueue('profile_update', {
        'display_name': displayName,
        'email': email,
      });

      // Attempt to sync immediately
      await _syncService.performPeriodicSync();
    } catch (e) {
      debugPrint('Profile update error: $e');
      rethrow;
    }
  }

  // Retry failed sync operations
  static Future<void> retrySyncOperations() async {
    try {
      final syncQueue = await LocalStorageService.getSyncQueue();

      for (var item in syncQueue) {
        switch (item['type']) {
          case 'signup':
            // Implement retry logic for signup
            break;
          case 'login':
            // Implement retry logic for login
            break;
          case 'password_reset':
            // Implement retry logic for password reset
            break;
          case 'profile_update':
            // Implement retry logic for profile update
            break;
        }
      }

      // Clear sync queue after processing
      await LocalStorageService.clearSyncQueueItems(syncQueue);
    } catch (e) {
      debugPrint('Sync retry error: $e');
    }
  }
}
