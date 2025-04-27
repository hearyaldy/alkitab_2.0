import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider for managing profile photo state
final profilePhotoProvider =
    StateNotifierProvider<ProfilePhotoNotifier, String?>((ref) {
  return ProfilePhotoNotifier();
});

class ProfilePhotoNotifier extends StateNotifier<String?> {
  ProfilePhotoNotifier() : super(null) {
    _initializeProfilePhoto();
  }

  // Initialize profile photo from user metadata or shared preferences
  Future<void> _initializeProfilePhoto() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final photoUrl = user.userMetadata?['profile_photo_url'];
        if (photoUrl != null) {
          state = photoUrl;
          return;
        }
      }

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedPhotoUrl = prefs.getString('profile_photo_url');
      if (savedPhotoUrl != null) {
        state = savedPhotoUrl;
      }
    } catch (e) {
      print('Error initializing profile photo: $e');
    }
  }

  // Update profile photo
  Future<void> updateProfilePhoto(String photoUrl) async {
    try {
      // Update in state
      state = photoUrl;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo_url', photoUrl);

      // Optional: Update Supabase user metadata
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth
            .updateUser(UserAttributes(data: {'profile_photo_url': photoUrl}));
      }
    } catch (e) {
      print('Error updating profile photo: $e');
    }
  }

  // Clear profile photo
  Future<void> clearProfilePhoto() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_photo_url');

    // Optional: Clear from Supabase user metadata
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(data: {'profile_photo_url': null}));
    }
  }
}
