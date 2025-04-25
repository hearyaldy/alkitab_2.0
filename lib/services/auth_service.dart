import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';
import '../config/constants.dart';

class AuthService {
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
        await LocalStorageService.saveValue(
          AppConstants.userBoxName,
          'currentUser',
          response.user!.toJson(),
        );

        // Save additional profile info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        if (displayName != null) {
          await prefs.setString('user_display_name', displayName);
        }
      }

      return response.user;
    } catch (e) {
      debugPrint('Sign up error: $e');
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
        await LocalStorageService.saveValue(
          AppConstants.userBoxName,
          'currentUser',
          response.user!.toJson(),
        );

        // Save to shared preferences for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setBool('is_logged_in', true);
      }

      return response.user;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await SupabaseService.auth.signOut();

      // Clear user from local storage
      await LocalStorageService.deleteValue(
          AppConstants.userBoxName, 'currentUser');

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('is_logged_in');
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await SupabaseService.auth.resetPasswordForEmail(email);
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

    return LocalStorageService.getValue(
      AppConstants.userBoxName,
      'currentUser',
    );
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

      // Update Supabase user
      await SupabaseService.auth.updateUser(
        UserAttributes(
          email: email,
          data: {
            'display_name': displayName,
          },
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
    } catch (e) {
      debugPrint('Profile update error: $e');
      rethrow;
    }
  }
}
