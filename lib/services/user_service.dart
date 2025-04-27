import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
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
        'profile_photo_url': user.userMetadata?['profile_photo_url'],
      });
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  // Upload profile photo
  Future<String?> uploadProfilePhoto(File imageFile) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final fileName = 'profile-images/profile_${user.id}.jpg';

      // Upload the file
      await _supabase.storage.from('profile-images').upload(fileName, imageFile,
          fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl =
          _supabase.storage.from('profile-images').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      return null;
    }
  }

  // Update user profile
  Future<UserModel?> updateProfile({
    String? displayName,
    String? preferredBibleVersion,
    String? profilePhotoUrl,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Prepare user metadata updates
      final userMetadata = <String, dynamic>{};

      if (displayName != null) {
        userMetadata['display_name'] = displayName;
      }
      if (preferredBibleVersion != null) {
        userMetadata['preferred_bible_version'] = preferredBibleVersion;
      }
      if (profilePhotoUrl != null) {
        userMetadata['profile_photo_url'] = profilePhotoUrl;
      }

      // Update Supabase user metadata
      await _supabase.auth.updateUser(
        UserAttributes(data: userMetadata),
      );

      // Update local preferences
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null) {
        await prefs.setString('user_display_name', displayName);
      }
      if (preferredBibleVersion != null) {
        await prefs.setString('preferred_bible_version', preferredBibleVersion);
      }
      if (profilePhotoUrl != null) {
        await prefs.setString('profile_photo_url', profilePhotoUrl);
      }

      // Fetch and return updated profile
      return await fetchUserProfile();
    } catch (e) {
      debugPrint('Error updating user profile: $e');
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

      final lastReadPosition = {
        'bookId': bookId,
        'chapterId': chapterId,
        'timestamp': DateTime.now().toIso8601String()
      };

      await prefs.setString(
          'last_read_position', json.encode(lastReadPosition));

      await _supabase.from('profiles').update({
        'last_read_position': {
          'book_id': bookId,
          'chapter_id': chapterId,
          'timestamp': DateTime.now().toIso8601String()
        }
      }).eq('user_id', user.id);
    } catch (e) {
      debugPrint('Error saving last read position: $e');
    }
  }

  // Retrieve last read position
  Future<Map<String, dynamic>?> getLastReadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReadPositionString = prefs.getString('last_read_position');

      if (lastReadPositionString != null) {
        return json.decode(lastReadPositionString);
      }

      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('last_read_position')
          .eq('user_id', user.id)
          .single();

      return response['last_read_position'];
    } catch (e) {
      debugPrint('Error retrieving last read position: $e');
      return null;
    }
  }

  // Delete user account
  Future<bool> deleteAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Optional: Delete user-related data from other tables
      await _supabase.from('profiles').delete().eq('user_id', user.id);

      // Delete user's profile image from storage
      final fileName = 'profile-images/profile_${user.id}.jpg';
      await _supabase.storage.from('profile-images').remove([fileName]);

      // Delete the user account
      await _supabase.auth.admin.deleteUser(user.id);

      // Clear local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      return true;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }
}
