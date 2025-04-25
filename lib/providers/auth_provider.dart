import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(Supabase.instance.client.auth.currentUser);

  // SIGN IN
  Future<void> signIn(String email, String password) async {
    final response = await AuthService.signIn(
      email: email,
      password: password,
    );
    state = response;
  }

  // SIGN UP with username support
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await AuthService.signUp(
      email: email,
      password: password,
      displayName: username,
    );

    state = response;
  }

  // RESET PASSWORD
  Future<void> resetPassword(String email) async {
    await AuthService.resetPassword(email);
  }

  // SIGN OUT
  Future<void> signOut() async {
    await AuthService.signOut();
    state = null;
  }

  // UPDATE PROFILE
  Future<void> updateProfile({
    String? displayName,
    String? email,
  }) async {
    await AuthService.updateProfile(
      displayName: displayName,
      email: email,
    );

    // Refresh current user state
    state = Supabase.instance.client.auth.currentUser;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});
