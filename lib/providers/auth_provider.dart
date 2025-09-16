import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';

// Provider for FirebaseService instance
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// Stream provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Provider for current user
final currentUserProvider = StateProvider<User?>((ref) {
  return FirebaseAuth.instance.currentUser;
});

class AuthNotifier extends StateNotifier<User?> {
  final FirebaseService _firebaseService;

  AuthNotifier(this._firebaseService)
      : super(FirebaseAuth.instance.currentUser);

  // SIGN IN with email
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final credential =
          await _firebaseService.signInWithEmailPassword(email, password);
      if (credential != null) {
        state = credential.user;
        return true;
      }
      return false;
    } catch (e) {
      print('Error signing in: $e');
      return false;
    }
  }

  // SIGN IN with Google
  Future<bool> signInWithGoogle() async {
    try {
      final credential = await _firebaseService.signInWithGoogle();
      if (credential != null) {
        state = credential.user;
        return true;
      }
      return false;
    } catch (e) {
      print('Error signing in with Google: $e');
      return false;
    }
  }

  // SIGN UP
  Future<bool> signUp(String email, String password, String displayName) async {
    try {
      final credential =
          await _firebaseService.signUpWithEmailPassword(email, password);
      if (credential != null) {
        await credential.user?.updateDisplayName(displayName);
        state = credential.user;
        return true;
      }
      return false;
    } catch (e) {
      print('Error signing up: $e');
      return false;
    }
  }

  // RESET PASSWORD
  Future<bool> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    await _firebaseService.signOut();
    state = null;
  }

  // UPDATE PROFILE
  Future<bool> updateProfile({String? displayName, String? email}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (email != null) {
          await user.updateEmail(email);
        }
        state = FirebaseAuth.instance.currentUser;
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return AuthNotifier(firebaseService);
});
