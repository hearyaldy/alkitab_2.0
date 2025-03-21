import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'local_storage_service.dart';
import '../config/constants.dart';

class AuthService {
  // Sign up with email and password
  static Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await SupabaseService.auth.signUp(
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
      await LocalStorageService.deleteValue(AppConstants.userBoxName, 'currentUser');
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
  static Map<String, dynamic>? getCurrentUserFromStorage() {
    return LocalStorageService.getValue(
      AppConstants.userBoxName,
      'currentUser',
    );
  }
  
  // Check if user is authenticated (either online or from local storage)
  static bool isAuthenticated() {
    if (SupabaseService.isAuthenticated) return true;
    
    // Check local storage
    final user = getCurrentUserFromStorage();
    return user != null;
  }
}