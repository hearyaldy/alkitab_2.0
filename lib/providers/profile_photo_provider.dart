import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Provider for managing profile photo state
final profilePhotoProvider =
    StateNotifierProvider<ProfilePhotoNotifier, String?>((ref) {
  return ProfilePhotoNotifier();
});

class ProfilePhotoNotifier extends StateNotifier<String?> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProfilePhotoNotifier() : super(null) {
    _initializeProfilePhoto();
  }

  // Initialize profile photo from user metadata or shared preferences
  Future<void> _initializeProfilePhoto() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // First try to get from Firebase Auth photoURL
        if (user.photoURL != null) {
          state = user.photoURL;
          return;
        }

        // Then try to get from Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final photoUrl = userDoc.data()?['profile_photo_url'];
          if (photoUrl != null) {
            state = photoUrl;
            return;
          }
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

      // Update Firebase Auth photoURL
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePhotoURL(photoUrl);

        // Also store in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'profile_photo_url': photoUrl,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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

    // Clear from Firebase
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePhotoURL(null);

      // Also clear from Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profile_photo_url': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
