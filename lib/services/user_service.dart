// lib/services/user_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class UserService {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UserModel?> fetchUserProfile() async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('profiles').doc(user.uid).get();

      Map<String, dynamic> profileData = {};
      if (doc.exists) {
        profileData = doc.data() ?? {};
      }

      return UserModel.fromJson({
        ...profileData,
        'id': user.uid,
        'email': user.email ?? '',
        'created_at': user.metadata.creationTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'profile_photo_url': user.photoURL ?? profileData['profile_photo_url'],
        'display_name': user.displayName ?? profileData['display_name'] ?? '',
      });
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  Future<String?> uploadProfilePhoto(File imageFile) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return null;

      final fileName = 'profile-images/profile_${user.uid}.jpg';
      final ref = _storage.ref().child(fileName);

      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      return null;
    }
  }

  Future<UserModel?> updateProfile({
    String? displayName,
    String? preferredBibleVersion,
    String? profilePhotoUrl,
  }) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return null;

      final profileData = <String, dynamic>{};

      if (displayName != null) {
        profileData['display_name'] = displayName;
        try {
          await user.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('Error updating display name: $e');
          // Continue with Firestore update even if Firebase Auth update fails
        }
      }
      if (preferredBibleVersion != null) {
        profileData['preferred_bible_version'] = preferredBibleVersion;
      }
      if (profilePhotoUrl != null) {
        profileData['profile_photo_url'] = profilePhotoUrl;
        try {
          await user.updatePhotoURL(profilePhotoUrl);
        } catch (e) {
          debugPrint('Error updating photo URL: $e');
          // Continue with Firestore update even if Firebase Auth update fails
        }
      }

      // Update Firestore profile
      if (profileData.isNotEmpty) {
        await _firestore.collection('profiles').doc(user.uid).set(
          profileData,
          SetOptions(merge: true),
        );
      }

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

      return await fetchUserProfile();
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return null;
    }
  }

  Future<void> saveLastReadPosition({
    required String bookId,
    required int chapterId,
  }) async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      final lastReadPosition = {
        'bookId': bookId,
        'chapterId': chapterId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(
          'last_read_position', json.encode(lastReadPosition));

      await _firestore.collection('profiles').doc(user.uid).set({
        'last_read_position': {
          'book_id': bookId,
          'chapter_id': chapterId,
          'timestamp': DateTime.now().toIso8601String(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving last read position: $e');
    }
  }

  Future<Map<String, dynamic>?> getLastReadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReadPositionString = prefs.getString('last_read_position');

      if (lastReadPositionString != null) {
        return json.decode(lastReadPositionString);
      }

      final user = _firebaseService.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('profiles').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return data?['last_read_position'];
    } catch (e) {
      debugPrint('Error retrieving last read position: $e');
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return false;

      // Delete profile from Firestore
      await _firestore.collection('profiles').doc(user.uid).delete();

      // Delete profile photo from Storage
      try {
        final fileName = 'profile-images/profile_${user.uid}.jpg';
        await _storage.ref().child(fileName).delete();
      } catch (e) {
        debugPrint('Profile photo not found or error deleting: $e');
      }

      // Delete user account
      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      return true;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }
}
