import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Workaround class for Firebase Auth casting bug
class FakeUserCredential implements UserCredential {
  @override
  final User user;

  FakeUserCredential(this.user);

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  AuthCredential? get credential => null;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _saveUserData(credential.user);
      }
      return credential;
    } catch (e) {
      // Check if this is the specific PigeonUserDetails casting error
      final errorString = e.toString();
      if (errorString.contains('PigeonUserDetails') && errorString.contains('type cast')) {
        debugPrint('Firebase Auth internal casting error detected, but user might be signed in');

        // Wait a moment for Firebase to process the authentication
        await Future.delayed(const Duration(milliseconds: 500));

        // Check if user is actually signed in despite the error
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          debugPrint('User is actually signed in: ${currentUser.email}');
          await _saveUserData(currentUser);

          // Create a mock credential since the real one failed to cast
          // We know the sign-in was successful because currentUser exists
          return FakeUserCredential(currentUser);
        }
      }
      debugPrint('Sign in error: $e');
      return null;
    }
  }

  // Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google sign in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('Failed to get Google authentication tokens');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _saveUserData(userCredential.user);
      }
      return userCredential;
    } catch (e) {
      // Handle the same PigeonUserDetails error for Google Sign In
      final errorString = e.toString();
      if (errorString.contains('PigeonUserDetails') && errorString.contains('type cast')) {
        debugPrint('Firebase Auth Google sign in casting error detected');
        await Future.delayed(const Duration(milliseconds: 500));

        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          debugPrint('Google user is actually signed in: ${currentUser.email}');
          await _saveUserData(currentUser);
          return FakeUserCredential(currentUser);
        }
      }
      debugPrint('Google sign in error: $e');
      return null;
    }
  }

  // Sign up with email and password
  static Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        try {
          await credential.user!.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('Error updating display name: $e');
        }
        await _saveUserData(credential.user);
      }
      return credential;
    } catch (e) {
      debugPrint('Sign up error: $e');
      return null;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await _clearUserData();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      debugPrint('Attempting to send password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent successfully to: $email');
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  // Update profile
  static Future<void> updateProfile({
    String? displayName,
    String? email,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) {
          try {
            await user.updateDisplayName(displayName);
            debugPrint('Display name updated successfully');
          } catch (e) {
            debugPrint('Error updating display name: $e');
          }
        }
        if (email != null) {
          try {
            await user.updateEmail(email);
            debugPrint('Email updated successfully');
          } catch (e) {
            debugPrint('Error updating email: $e');
          }
        }

        // Reload user to get updated info, but handle potential errors
        try {
          await user.reload();
          final updatedUser = _auth.currentUser;
          await _saveUserData(updatedUser);
        } catch (e) {
          debugPrint('Error reloading user: $e');
          // Still save with current user data
          await _saveUserData(user);
        }
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }

  // Save user data to local storage
  static Future<void> _saveUserData(User? user) async {
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user.email ?? '');
      await prefs.setString('user_display_name', user.displayName ?? '');
      await prefs.setString('user_id', user.uid);
      await prefs.setBool('is_logged_in', true);
      debugPrint('User data saved successfully for: ${user.email}');
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  // Clear user data from local storage
  static Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_display_name');
    await prefs.remove('user_id');
    await prefs.remove('is_logged_in');
  }
}
