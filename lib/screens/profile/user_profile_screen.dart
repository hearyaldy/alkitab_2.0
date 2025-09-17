import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/user_service.dart';

final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final userService = UserService();
  final profile = await userService.fetchUserProfile();

  if (profile == null) return null;

  return UserProfile(
    name: profile.displayName ?? '',
    email: profile.email ?? '',
  );
});

class UserProfile {
  final String name;
  final String email;

  UserProfile({required this.name, required this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }
}
