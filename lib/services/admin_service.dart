// lib/services/admin_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum UserRole {
  user,
  admin,
  superadmin,
}

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Superadmin email
  static const String superadminEmail = 'heary@hopetv.asia';

  // Check if current user is superadmin
  bool get isSuperadmin {
    final user = _auth.currentUser;
    return user?.email == superadminEmail;
  }

  // Check if current user is admin or superadmin
  Future<bool> get isAdmin async {
    if (isSuperadmin) return true;

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // First check if they have an existing role
      final doc = await _firestore.collection('user_roles').doc(user.uid).get();
      final role = doc.data()?['role'] as String?;
      if (role == 'admin' || role == 'superadmin') return true;

      // Check if they have a pending admin role by email
      if (user.email != null) {
        await _checkAndActivatePendingAdmin(user.email!, user.uid);

        // Check again after potential activation
        final updatedDoc = await _firestore.collection('user_roles').doc(user.uid).get();
        final updatedRole = updatedDoc.data()?['role'] as String?;
        return updatedRole == 'admin' || updatedRole == 'superadmin';
      }

      return false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Check and activate pending admin role
  Future<void> _checkAndActivatePendingAdmin(String email, String userId) async {
    try {
      final pendingDoc = await _firestore.collection('pending_admin_emails').doc(email).get();
      if (pendingDoc.exists) {
        final data = pendingDoc.data()!;
        final role = data['role'] as String? ?? 'admin';

        // Create the actual user role
        await _firestore.collection('user_roles').doc(userId).set({
          'role': role,
          'email': email,
          'activated_at': FieldValue.serverTimestamp(),
          'originally_created_at': data['created_at'],
        });

        // Mark the pending email as activated
        await _firestore.collection('pending_admin_emails').doc(email).update({
          'status': 'activated',
          'activated_at': FieldValue.serverTimestamp(),
          'user_id': userId,
        });

        debugPrint('Activated pending admin role for $email');
      }
    } catch (e) {
      debugPrint('Error checking pending admin: $e');
    }
  }

  // Get user role
  Future<UserRole> getUserRole() async {
    if (isSuperadmin) return UserRole.superadmin;

    final user = _auth.currentUser;
    if (user == null) return UserRole.user;

    try {
      final doc = await _firestore.collection('user_roles').doc(user.uid).get();
      final roleString = doc.data()?['role'] as String?;

      switch (roleString) {
        case 'superadmin':
          return UserRole.superadmin;
        case 'admin':
          return UserRole.admin;
        default:
          return UserRole.user;
      }
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return UserRole.user;
    }
  }

  // Set user role (only superadmin can do this)
  Future<bool> setUserRole(String userId, UserRole role) async {
    if (!isSuperadmin) {
      debugPrint('Only superadmin can set user roles');
      return false;
    }

    try {
      await _firestore.collection('user_roles').doc(userId).set({
        'role': role.name,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _auth.currentUser?.uid,
      });
      return true;
    } catch (e) {
      debugPrint('Error setting user role: $e');
      return false;
    }
  }

  // Initialize superadmin role if not exists
  Future<void> initializeSuperadmin() async {
    final user = _auth.currentUser;
    if (user?.email == superadminEmail) {
      try {
        await _firestore.collection('user_roles').doc(user!.uid).set({
          'role': 'superadmin',
          'email': user.email,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error initializing superadmin: $e');
      }
    }
  }

  // Get all admin users (only superadmin can access)
  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    if (!isSuperadmin) return [];

    try {
      final snapshot = await _firestore
          .collection('user_roles')
          .where('role', whereIn: ['admin', 'superadmin'])
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('Error getting admin users: $e');
      return [];
    }
  }
}