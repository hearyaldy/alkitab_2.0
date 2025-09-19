// lib/services/sample_data_uploader.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SampleDataUploader {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> uploadSampleDevotionals() async {
    try {
      // Load sample devotionals from JSON file
      final String jsonString = await rootBundle.loadString('sample_devotionals.json');
      final List<dynamic> devotionalsList = jsonDecode(jsonString);

      // Check if devotionals already exist
      final existingSnapshot = await _firestore.collection('devotionals').limit(1).get();
      if (existingSnapshot.docs.isNotEmpty) {
        debugPrint('Devotionals already exist in database. Skipping upload.');
        return true;
      }

      // Upload each devotional
      int uploadedCount = 0;
      for (var devotionalData in devotionalsList) {
        try {
          final docId = devotionalData['id'] as String;
          await _firestore
              .collection('devotionals')
              .doc(docId)
              .set(devotionalData as Map<String, dynamic>);
          uploadedCount++;
          debugPrint('Uploaded devotional: ${devotionalData['title']}');
        } catch (e) {
          debugPrint('Error uploading devotional ${devotionalData['id']}: $e');
        }
      }

      debugPrint('Successfully uploaded $uploadedCount sample devotionals');
      return uploadedCount > 0;
    } catch (e) {
      debugPrint('Error uploading sample devotionals: $e');
      return false;
    }
  }

  static Future<bool> createSampleUserRole(String userEmail, String userId) async {
    try {
      await _firestore.collection('user_roles').doc(userId).set({
        'role': 'superadmin',
        'email': userEmail,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('Created superadmin role for $userEmail');
      return true;
    } catch (e) {
      debugPrint('Error creating user role: $e');
      return false;
    }
  }
}