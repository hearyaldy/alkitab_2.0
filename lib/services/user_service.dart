import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  // Fetch user profile from Supabase
  Future<UserModel?> fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .single();

      return UserModel.fromJson({
        ...response,
        'id': user.id,
        'email': user.email,
        'created_at': user.createdAt,
      });
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<UserModel?> updateProfile({
    String? displayName,
    String? preferredBibleVersion,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Update Supabase user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'display_name': displayName,
            'preferred_bible_version': preferredBibleVersion,
          },
        ),
      );

      // Update local preferences
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null) {
        await prefs.setString('user_display_name', displayName);
      }
      if (preferredBibleVersion != null) {
        await prefs.setString('preferred_bible_version', preferredBibleVersion);
      }

      // Fetch and return updated profile
      return await fetchUserProfile();
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  // Save last read position
  Future<void> saveLastReadPosition({
    required String bookId,
    required int chapterId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_read_position',
          '{"bookId": "$bookId", "chapterId": $chapterId}');

      // Optional: Sync with Supabase
      await _supabase.from('profiles').update({
        'last_read_position': {'book_id': bookId, 'chapter_id': chapterId}
      }).eq('user_id', user.id);
    } catch (e) {
      print('Error saving last read position: $e');
    }
  }
}
