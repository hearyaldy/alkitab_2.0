import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('user_id', userId)
      .single()
      .execute();

  if (response.error != null) {
    throw Exception('Error fetching user profile: ${response.error?.message}');
  }

  return UserProfile.fromJson(
      response.data); // Assuming you have a UserProfile model
});

class UserProfile {
  final String name;
  final String email;

  UserProfile({required this.name, required this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      email: json['email'],
    );
  }
}
