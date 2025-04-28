// lib/services/sync_queue_processor.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'connectivity_service.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

/// Represents different types of sync operations
enum SyncOperationType {
  bookmark,
  highlight,
  note,
  userProfile,
  readingProgress,
  devotionalBookmark
}

/// Detailed sync queue item with enhanced metadata
class SyncQueueItem {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;
  SyncStatus status;

  SyncQueueItem({
    required this.id,
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
        'status': status.toString(),
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'],
        type: SyncOperationType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => SyncOperationType.bookmark,
        ),
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp']),
        retryCount: json['retryCount'] ?? 0,
        status: SyncStatus.values.firstWhere(
          (e) => e.toString() == json['status'],
          orElse: () => SyncStatus.pending,
        ),
      );
}

/// Sync status for tracking synchronization progress
enum SyncStatus { pending, processing, completed, failed }

/// Comprehensive Sync Queue Processor
class SyncQueueProcessor {
  final ConnectivityService _connectivityService;
  final _supabase = Supabase.instance.client;

  // Maximum number of retry attempts for a sync operation
  static const int _maxRetryAttempts = 3;

  // Delay between retry attempts (in seconds)
  static const List<int> _retryDelays = [5, 15, 30];

  SyncQueueProcessor(this._connectivityService);

  /// Process the entire sync queue
  Future<void> processQueue() async {
    // Check if online
    if (!_connectivityService.isOnline) {
      debugPrint('Sync Queue: Offline - Skipping sync');
      return;
    }

    try {
      final box = await Hive.openBox('sync_queue');
      final queueItems = box.values
          .map(
              (item) => SyncQueueItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      for (var item in queueItems) {
        await _processSingleItem(item, box);
      }
    } catch (e) {
      debugPrint('Sync Queue Processing Error: $e');
    }
  }

  /// Process a single sync queue item
  Future<void> _processSingleItem(SyncQueueItem item, Box box) async {
    try {
      // Update status to processing
      item.status = SyncStatus.processing;

      // Perform sync based on operation type
      switch (item.type) {
        case SyncOperationType.bookmark:
          await _syncBookmark(item);
          break;
        case SyncOperationType.highlight:
          await _syncHighlight(item);
          break;
        case SyncOperationType.note:
          await _syncNote(item);
          break;
        case SyncOperationType.userProfile:
          await _syncUserProfile(item);
          break;
        case SyncOperationType.readingProgress:
          await _syncReadingProgress(item);
          break;
        case SyncOperationType.devotionalBookmark:
          await _syncDevotionalBookmark(item);
          break;
      }

      // Mark as completed and remove from queue
      item.status = SyncStatus.completed;
      await box.delete(item.id);

      debugPrint('Sync completed for ${item.type}');
    } catch (e) {
      // Handle retry logic
      if (item.retryCount < _maxRetryAttempts) {
        item.retryCount++;
        item.status = SyncStatus.failed;

        // Implement exponential backoff
        final delay = _retryDelays[item.retryCount - 1];
        await Future.delayed(Duration(seconds: delay));

        debugPrint(
            'Retrying sync for ${item.type}. Attempt ${item.retryCount}');

        // Update the item in the box
        await box.put(item.id, item.toJson());
      } else {
        // Max retries reached, remove from queue
        await box.delete(item.id);
        debugPrint(
            'Max retries reached for ${item.type}. Removing from queue.');
      }
    }
  }

  /// Sync bookmarks to Supabase
  Future<void> _syncBookmark(SyncQueueItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('user_bookmarks').upsert({
      ...item.data,
      'user_id': user.id,
    });
  }

  /// Sync highlights to Supabase
  Future<void> _syncHighlight(SyncQueueItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('user_highlights').upsert({
      ...item.data,
      'user_id': user.id,
    });
  }

  /// Sync notes to Supabase
  Future<void> _syncNote(SyncQueueItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('user_notes').upsert({
      ...item.data,
      'user_id': user.id,
    });
  }

  /// Sync user profile to Supabase
  Future<void> _syncUserProfile(SyncQueueItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Update user metadata
    await _supabase.auth.updateUser(
      UserAttributes(
        data: item.data,
      ),
    );
  }

  /// Sync reading progress to Supabase
  Future<void> _syncReadingProgress(SyncQueueItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('reading_progress').upsert({
      ...item.data,
      'user_id': user.id,
    });
  }

  /// Sync devotional bookmarks to Supabase
  Future<void> _syncDevotionalBookmark(SyncQueueItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('user_bookmarks').upsert({
      ...item.data,
      'user_id': user.id,
      'type': 'devotional',
    });
  }

  /// Add an item to the sync queue
  Future<void> addToQueue({
    required SyncOperationType type,
    required Map<String, dynamic> data,
  }) async {
    final box = await Hive.openBox('sync_queue');

    final item = SyncQueueItem(
      id: DateTime.now().toIso8601String(),
      type: type,
      data: data,
    );

    await box.put(item.id, item.toJson());

    debugPrint('Added to sync queue: ${type.toString()}');
  }

  /// Start periodic sync
  void startPeriodicSync() {
    // Run sync every 30 minutes
    Timer.periodic(Duration(minutes: 30), (_) {
      if (_connectivityService.isOnline) {
        processQueue();
      }
    });

    // Listen to connectivity changes
    _connectivityService.connectionStatusStream.listen((isOnline) {
      if (isOnline) {
        processQueue();
      }
    });
  }
}

/// Extension method to add sync queue operations to different services
extension SyncQueueExtension on LocalStorageService {
  /// Convenience method to add items to sync queue
  static Future<void> queueSync({
    required SyncOperationType type,
    required Map<String, dynamic> data,
  }) async {
    final box = await Hive.openBox('sync_queue');

    final item = SyncQueueItem(
      id: DateTime.now().toIso8601String(),
      type: type,
      data: data,
    );

    await box.put(item.id, item.toJson());
  }
}
