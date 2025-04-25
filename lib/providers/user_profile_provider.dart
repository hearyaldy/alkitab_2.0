import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProfileNotifier extends StateNotifier<UserModel?> {
  final UserService _userService;

  UserProfileNotifier(this._userService) : super(null);

  // Fetch user profile
  Future<void> fetchProfile() async {
    try {
      final profile = await _userService.fetchUserProfile();
      state = profile;
    } catch (e) {
      state = null;
      print('Error fetching profile: $e');
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? preferredBibleVersion,
  }) async {
    try {
      final updatedProfile = await _userService.updateProfile(
        displayName: displayName,
        preferredBibleVersion: preferredBibleVersion,
      );

      if (updatedProfile != null) {
        state = updatedProfile;
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserModel?>((ref) {
  return UserProfileNotifier(UserService());
});
