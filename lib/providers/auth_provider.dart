import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider; // Hide Provider from Supabase
import '../services/auth_service.dart';

// Auth state notifier
class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(null) {
    // Initialize state from Supabase
    initialize();
  }

  Future<void> initialize() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    state = currentUser;
  }

  Future<void> signUp(String email, String password) async {
    final user = await AuthService.signUp(email: email, password: password);
    state = user;
  }

  Future<void> signIn(String email, String password) async {
    final user = await AuthService.signIn(email: email, password: password);
    state = user;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = null;
  }
  
  Future<void> resetPassword(String email) async {
    await AuthService.resetPassword(email);
  }
  
  bool get isAuthenticated => state != null;
}

// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});

// Provider for auth state as a boolean
final isAuthenticatedProvider = StateProvider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState != null;
});