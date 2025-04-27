import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

// Enum for profile status
enum UserProfileStatus { initial, loading, loaded, error }

// State class for comprehensive profile management
class UserProfileState {
  final UserModel? user;
  final UserProfileStatus status;
  final String? errorMessage;

  UserProfileState({
    this.user,
    this.status = UserProfileStatus.initial,
    this.errorMessage,
  });

  // Factory constructor for initial state
  factory UserProfileState.initial() => UserProfileState(
        user: null,
        status: UserProfileStatus.initial,
        errorMessage: null,
      );

  // Immutable state update
  UserProfileState copyWith({
    UserModel? user,
    UserProfileStatus? status,
    String? errorMessage,
  }) {
    return UserProfileState(
      user: user ?? this.user,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final UserService _userService;

  UserProfileNotifier(this._userService) : super(UserProfileState.initial());

  // Fetch user profile
  Future<void> fetchProfile() async {
    try {
      state = state.copyWith(status: UserProfileStatus.loading);

      final profile = await _userService.fetchUserProfile();

      state = state.copyWith(
          status: UserProfileStatus.loaded, user: profile, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
          status: UserProfileStatus.error,
          errorMessage: 'Failed to fetch profile: ${e.toString()}',
          user: null);
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? preferredBibleVersion,
    File? profilePhoto,
  }) async {
    try {
      state = state.copyWith(status: UserProfileStatus.loading);

      // Handle profile photo upload if provided
      String? photoUrl;
      if (profilePhoto != null) {
        photoUrl = await _userService.uploadProfilePhoto(profilePhoto);
      }

      // Update profile with potential photo URL
      final updatedProfile = await _userService.updateProfile(
          displayName: displayName,
          preferredBibleVersion: preferredBibleVersion,
          profilePhotoUrl: photoUrl);

      if (updatedProfile != null) {
        state = state.copyWith(
            status: UserProfileStatus.loaded,
            user: updatedProfile,
            errorMessage: null);
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      state = state.copyWith(
          status: UserProfileStatus.error,
          errorMessage: 'Profile update failed: ${e.toString()}');
    }
  }

  // Reset profile state
  void resetProfile() {
    state = UserProfileState.initial();
  }
}

// Provider for user profile state management
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(UserService());
});
