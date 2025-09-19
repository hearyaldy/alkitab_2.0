// lib/services/devotional_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/devotional_model.dart';
import 'mock_data_service.dart';
import 'offline_cache_service.dart';

class DevotionalService {
  static final DevotionalService _instance = DevotionalService._internal();

  // Singleton pattern
  factory DevotionalService() {
    return _instance;
  }

  DevotionalService._internal();

  // Cache devotionals to avoid frequent reloading
  List<DevotionalModel> _cachedDevotionals = [];
  DateTime? _lastLoaded;

  // Firebase instances
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineCacheService _cacheService = OfflineCacheService();

  // Get all devotionals (offline-first approach)
  Future<List<DevotionalModel>> getAllDevotionals({bool forceRefresh = false}) async {
    try {
      // Use offline-first caching
      final devotionals = await _cacheService.getDevotionals(forceRefresh: forceRefresh);

      if (devotionals.isNotEmpty) {
        _cachedDevotionals = devotionals;
        _lastLoaded = DateTime.now();
        return devotionals;
      }

      // If cache service returns empty, try Firebase Storage as backup
      debugPrint('Cache service returned empty, trying Firebase Storage...');
      final ListResult result = await _storage.ref('devotional-readings').listAll();
      final List<DevotionalModel> storageDevotionals = [];

      for (final ref in result.items) {
        if (!ref.name.endsWith('.json')) continue;

        final data = await ref.getData();
        if (data == null) continue;

        final content = String.fromCharCodes(data);
        final parsed = jsonDecode(content);

        if (parsed is List) {
          for (var item in parsed) {
            try {
              final devotional = DevotionalModel.fromJson(item);
              storageDevotionals.add(devotional);

              // Store in Firestore for future reads
              await _firestore.collection('devotionals').doc(devotional.id).set(
                    item as Map<String, dynamic>,
                    SetOptions(merge: true),
                  );
            } catch (e) {
              debugPrint('Error parsing devotional: $e');
            }
          }
        }
      }

      if (storageDevotionals.isNotEmpty) {
        _cachedDevotionals = storageDevotionals;
        _lastLoaded = DateTime.now();
        return storageDevotionals;
      }
    } catch (e) {
      debugPrint('Failed to load devotionals: $e');
    }

    // Fallback to mock data if all else fails
    debugPrint('Using mock devotional data as fallback');
    await MockDataService.initialize();
    final mockDevotionals = MockDataService.getDevotionals();

    _cachedDevotionals = mockDevotionals;
    _lastLoaded = DateTime.now();

    return mockDevotionals;
  }

  // Get a specific devotional by ID
  Future<DevotionalModel?> getDevotionalById(String id) async {
    try {
      // Check cache first
      if (_cachedDevotionals.isNotEmpty) {
        try {
          return _cachedDevotionals.firstWhere((d) => d.id == id);
        } catch (e) {
          // Not found in cache
        }
      }

      // Try Firestore
      final doc = await _firestore.collection('devotionals').doc(id).get();
      if (doc.exists) {
        return DevotionalModel.fromJson(doc.data()!);
      }

      // If not found in Firestore, try getting all devotionals
      final devotionals = await getAllDevotionals();
      return devotionals.firstWhere((d) => d.id == id);
    } catch (e) {
      debugPrint('Error getting devotional by ID: $e');
      return null;
    }
  }

  // Get today's devotional
  Future<DevotionalModel?> getTodayDevotional() async {
    try {
      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

      // Try to get from Firestore first
      final snapshot = await _firestore
          .collection('devotionals')
          .where('day_of_year', isEqualTo: dayOfYear)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DevotionalModel.fromJson(snapshot.docs.first.data());
      }

      // If not found, fall back to the modulo method
      final devotionals = await getAllDevotionals();
      if (devotionals.isEmpty) {
        await MockDataService.initialize();
        return MockDataService.getTodayDevotional();
      }

      final index = dayOfYear % devotionals.length;
      return devotionals[index];
    } catch (e) {
      debugPrint('Error getting today\'s devotional: $e');
      await MockDataService.initialize();
      return MockDataService.getTodayDevotional();
    }
  }

  // Get featured or recent devotionals
  Future<List<DevotionalModel>> getFeaturedDevotionals({int count = 5}) async {
    try {
      // Try to get from Firestore first
      final snapshot = await _firestore
          .collection('devotionals')
          .orderBy('date', descending: true)
          .limit(count)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => DevotionalModel.fromJson(doc.data()))
            .toList();
      }

      // If Firestore is empty, fall back to cached or fetched data
      final devotionals = await getAllDevotionals();
      if (devotionals.isEmpty) return [];

      devotionals.sort((a, b) => b.date.compareTo(a.date));
      return devotionals.take(count).toList();
    } catch (e) {
      debugPrint('Error getting featured devotionals: $e');
      final devotionals = await getAllDevotionals();
      devotionals.sort((a, b) => b.date.compareTo(a.date));
      return devotionals.take(count).toList();
    }
  }

  // Force refresh the cache
  Future<void> refreshCache() async {
    _cachedDevotionals = [];
    _lastLoaded = null;
    await getAllDevotionals(forceRefresh: true);
  }

  // Upload a new devotional
  Future<bool> uploadDevotional(DevotionalModel devotional) async {
    try {
      await _firestore
          .collection('devotionals')
          .doc(devotional.id)
          .set(devotional.toJson());

      // Invalidate cache to force refresh on next load
      await _cacheService.invalidateCache('devotionals');
      _cachedDevotionals = [];
      _lastLoaded = null;

      return true;
    } catch (e) {
      debugPrint('Error uploading devotional: $e');
      return false;
    }
  }

  // Update a devotional
  Future<bool> updateDevotional(DevotionalModel devotional) async {
    try {
      await _firestore
          .collection('devotionals')
          .doc(devotional.id)
          .update(devotional.toJson());

      // Update cached devotional if it exists
      final index = _cachedDevotionals.indexWhere((d) => d.id == devotional.id);
      if (index != -1) {
        _cachedDevotionals[index] = devotional;
      }

      // Invalidate cache to force refresh on next load
      await _cacheService.invalidateCache('devotionals');

      return true;
    } catch (e) {
      debugPrint('Error updating devotional: $e');
      return false;
    }
  }

  // Delete a devotional
  Future<bool> deleteDevotional(String id) async {
    try {
      await _firestore.collection('devotionals').doc(id).delete();

      // Invalidate cache to force refresh on next load
      await _cacheService.invalidateCache('devotionals');
      _cachedDevotionals.removeWhere((d) => d.id == id);
      _lastLoaded = null;

      return true;
    } catch (e) {
      debugPrint('Error deleting devotional: $e');
      return false;
    }
  }

  // Bulk delete devotionals
  Future<bool> bulkDeleteDevotionals(List<String> ids) async {
    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(_firestore.collection('devotionals').doc(id));
      }
      await batch.commit();

      // Update cache
      _cachedDevotionals.removeWhere((d) => ids.contains(d.id));
      await _cacheService.invalidateCache('devotionals');

      return true;
    } catch (e) {
      debugPrint('Error bulk deleting devotionals: $e');
      return false;
    }
  }

  // Bulk update devotionals
  Future<bool> bulkUpdateDevotionals(List<DevotionalModel> devotionals) async {
    try {
      final batch = _firestore.batch();
      for (final devotional in devotionals) {
        batch.update(
          _firestore.collection('devotionals').doc(devotional.id),
          devotional.toJson(),
        );
      }
      await batch.commit();

      // Update cache
      for (final devotional in devotionals) {
        final index = _cachedDevotionals.indexWhere((d) => d.id == devotional.id);
        if (index != -1) {
          _cachedDevotionals[index] = devotional;
        }
      }
      await _cacheService.invalidateCache('devotionals');

      return true;
    } catch (e) {
      debugPrint('Error bulk updating devotionals: $e');
      return false;
    }
  }
}
