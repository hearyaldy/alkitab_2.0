// lib/services/offline_cache_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/devotional_model.dart';

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  static const String _devotionalsBoxName = 'cached_devotionals';
  static const String _metadataBoxName = 'cache_metadata';
  static const String _bookmarksBoxName = 'cached_bookmarks';
  static const String _notesBoxName = 'cached_notes';

  // Cache validity periods (in hours)
  static const int _devotionalsCacheHours = 24; // 24 hours for devotionals
  static const int _bookmarksCacheHours = 1;    // 1 hour for bookmarks

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize all cache boxes
  Future<void> initialize() async {
    await _openBoxIfNeeded(_devotionalsBoxName);
    await _openBoxIfNeeded(_metadataBoxName);
    await _openBoxIfNeeded(_bookmarksBoxName);
    await _openBoxIfNeeded(_notesBoxName);
  }

  Future<void> _openBoxIfNeeded(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  // DEVOTIONALS CACHING
  Future<List<DevotionalModel>> getDevotionals({bool forceRefresh = false}) async {
    await _openBoxIfNeeded(_devotionalsBoxName);
    await _openBoxIfNeeded(_metadataBoxName);

    // Check if we have cached data and it's still valid
    if (!forceRefresh && _isCacheValid('devotionals', _devotionalsCacheHours)) {
      final cachedData = _getCachedDevotionals();
      if (cachedData.isNotEmpty) {
        debugPrint('Using cached devotionals (${cachedData.length} items)');
        return cachedData;
      }
    }

    try {
      // Try to fetch from Firestore
      debugPrint('Fetching devotionals from Firestore...');
      final snapshot = await _firestore
          .collection('devotionals')
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final devotionals = snapshot.docs
            .map((doc) => DevotionalModel.fromJson(doc.data()))
            .toList();

        // Cache the data
        await _cacheDevotionals(devotionals);
        debugPrint('Cached ${devotionals.length} devotionals');
        return devotionals;
      }
    } catch (e) {
      debugPrint('Error fetching devotionals from Firestore: $e');
      // Return cached data even if expired if network fails
      final cachedData = _getCachedDevotionals();
      if (cachedData.isNotEmpty) {
        debugPrint('Using expired cached devotionals due to network error');
        return cachedData;
      }
    }

    return [];
  }

  Future<void> _cacheDevotionals(List<DevotionalModel> devotionals) async {
    await _openBoxIfNeeded(_devotionalsBoxName);
    await _openBoxIfNeeded(_metadataBoxName);

    final devotionalsBox = Hive.box(_devotionalsBoxName);
    final metadataBox = Hive.box(_metadataBoxName);

    // Clear old data
    await devotionalsBox.clear();

    // Cache new data
    for (int i = 0; i < devotionals.length; i++) {
      await devotionalsBox.put(i, jsonEncode(devotionals[i].toJson()));
    }

    // Update metadata
    await metadataBox.put('devotionals_last_updated', DateTime.now().millisecondsSinceEpoch);
    await metadataBox.put('devotionals_count', devotionals.length);
  }

  List<DevotionalModel> _getCachedDevotionals() {
    final devotionalsBox = Hive.box(_devotionalsBoxName);
    final List<DevotionalModel> devotionals = [];

    for (int i = 0; i < devotionalsBox.length; i++) {
      try {
        final data = devotionalsBox.get(i);
        if (data != null) {
          final devotional = DevotionalModel.fromJson(jsonDecode(data));
          devotionals.add(devotional);
        }
      } catch (e) {
        debugPrint('Error parsing cached devotional at index $i: $e');
      }
    }

    return devotionals;
  }

  // BOOKMARKS CACHING
  Future<List<Map<String, dynamic>>> getBookmarks(String userId, {bool forceRefresh = false}) async {
    await _openBoxIfNeeded(_bookmarksBoxName);
    await _openBoxIfNeeded(_metadataBoxName);

    final cacheKey = 'bookmarks_$userId';

    // Check if we have cached data and it's still valid
    if (!forceRefresh && _isCacheValid(cacheKey, _bookmarksCacheHours)) {
      final cachedData = _getCachedBookmarks(userId);
      if (cachedData.isNotEmpty) {
        debugPrint('Using cached bookmarks for $userId (${cachedData.length} items)');
        return cachedData;
      }
    }

    try {
      debugPrint('Fetching bookmarks from Firestore for $userId...');
      final snapshot = await _firestore
          .collection('user_bookmarks')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      final bookmarks = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      // Cache the data
      await _cacheBookmarks(userId, bookmarks);
      debugPrint('Cached ${bookmarks.length} bookmarks for $userId');
      return bookmarks;
    } catch (e) {
      debugPrint('Error fetching bookmarks from Firestore: $e');
      // Return cached data even if expired if network fails
      final cachedData = _getCachedBookmarks(userId);
      if (cachedData.isNotEmpty) {
        debugPrint('Using expired cached bookmarks due to network error');
        return cachedData;
      }
    }

    return [];
  }

  Future<void> _cacheBookmarks(String userId, List<Map<String, dynamic>> bookmarks) async {
    await _openBoxIfNeeded(_bookmarksBoxName);
    await _openBoxIfNeeded(_metadataBoxName);

    final bookmarksBox = Hive.box(_bookmarksBoxName);
    final metadataBox = Hive.box(_metadataBoxName);

    final cacheKey = 'bookmarks_$userId';

    // Cache data
    await bookmarksBox.put(cacheKey, jsonEncode(bookmarks));

    // Update metadata
    await metadataBox.put('${cacheKey}_last_updated', DateTime.now().millisecondsSinceEpoch);
    await metadataBox.put('${cacheKey}_count', bookmarks.length);
  }

  List<Map<String, dynamic>> _getCachedBookmarks(String userId) {
    final bookmarksBox = Hive.box(_bookmarksBoxName);
    final cacheKey = 'bookmarks_$userId';

    try {
      final data = bookmarksBox.get(cacheKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error parsing cached bookmarks for $userId: $e');
    }

    return [];
  }

  // CACHE VALIDATION
  bool _isCacheValid(String key, int maxAgeHours) {
    final metadataBox = Hive.box(_metadataBoxName);
    final lastUpdated = metadataBox.get('${key}_last_updated');

    if (lastUpdated == null) return false;

    final lastUpdatedTime = DateTime.fromMillisecondsSinceEpoch(lastUpdated);
    final now = DateTime.now();
    final difference = now.difference(lastUpdatedTime);

    return difference.inHours < maxAgeHours;
  }

  // CACHE MANAGEMENT
  Future<void> clearCache({String? specific}) async {
    if (specific != null) {
      await _openBoxIfNeeded(specific);
      final box = Hive.box(specific);
      await box.clear();
      debugPrint('Cleared cache for $specific');
    } else {
      // Clear all caches
      await _openBoxIfNeeded(_devotionalsBoxName);
      await _openBoxIfNeeded(_metadataBoxName);
      await _openBoxIfNeeded(_bookmarksBoxName);
      await _openBoxIfNeeded(_notesBoxName);

      await Hive.box(_devotionalsBoxName).clear();
      await Hive.box(_metadataBoxName).clear();
      await Hive.box(_bookmarksBoxName).clear();
      await Hive.box(_notesBoxName).clear();
      debugPrint('Cleared all caches');
    }
  }

  Future<void> invalidateCache(String key) async {
    await _openBoxIfNeeded(_metadataBoxName);
    final metadataBox = Hive.box(_metadataBoxName);
    await metadataBox.delete('${key}_last_updated');
    debugPrint('Invalidated cache for $key');
  }

  // GET CACHE INFO
  Map<String, dynamic> getCacheInfo() {
    final metadataBox = Hive.box(_metadataBoxName);

    return {
      'devotionals': {
        'count': metadataBox.get('devotionals_count', defaultValue: 0),
        'lastUpdated': _getLastUpdatedString('devotionals'),
        'valid': _isCacheValid('devotionals', _devotionalsCacheHours),
      },
      'total_cache_size': _getTotalCacheSize(),
    };
  }

  String _getLastUpdatedString(String key) {
    final metadataBox = Hive.box(_metadataBoxName);
    final lastUpdated = metadataBox.get('${key}_last_updated');

    if (lastUpdated == null) return 'Never';

    final time = DateTime.fromMillisecondsSinceEpoch(lastUpdated);
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  int _getTotalCacheSize() {
    int totalSize = 0;
    try {
      totalSize += Hive.box(_devotionalsBoxName).length;
      totalSize += Hive.box(_bookmarksBoxName).length;
      totalSize += Hive.box(_notesBoxName).length;
      totalSize += Hive.box(_metadataBoxName).length;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
    return totalSize;
  }

  // PRELOAD DATA
  Future<void> preloadEssentialData() async {
    debugPrint('Preloading essential data...');

    // Preload devotionals if cache is empty or expired
    if (!_isCacheValid('devotionals', _devotionalsCacheHours)) {
      await getDevotionals();
    }

    debugPrint('Essential data preload completed');
  }
}