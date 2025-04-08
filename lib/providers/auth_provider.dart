import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(Supabase.instance.client.auth.currentUser);

  // SIGN IN
  Future<void> signIn(String email, String password) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    state = response.user;
  }

  // SIGN UP with username support
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      // Insert additional profile info to 'profiles' table
      await Supabase.instance.client.from('profiles').insert({
        'user_id': user.id,
        'name': username,
        'email': email,
      });
    }

    state = user;
  }

  // RESET PASSWORD
  Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  // SIGN OUT
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = null;
  }
}
