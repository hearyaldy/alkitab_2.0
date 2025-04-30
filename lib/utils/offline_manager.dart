// lib/utils/offline_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/local_storage_service.dart';
import '../config/constants.dart';

/// OfflineManager is responsible for coordinating offline data access,
/// optimizing storage, and managing the sync behavior.
class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();

  factory OfflineManager() => _instance;

  OfflineManager._internal();

  // Services
  final ConnectivityService _connectivityService = ConnectivityService();
  late final SyncService _syncService;

  // State management
  bool _initialized = false;
  bool _isSyncInProgress = false;
  final StreamController<OfflineStatus> _statusController =
      StreamController<OfflineStatus>.broadcast();

  // Cached data status
  Map<String, DateTime> _contentLastUpdated = {};

  // Getters
  Stream<OfflineStatus> get statusStream => _statusController.stream;
  bool get isOffline => !_connectivityService.isOnline;
  bool get isSyncInProgress => _isSyncInProgress;

  /// Initialize the offline manager
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('OfflineManager: Initializing...');

    // Ensure local storage is initialized
    await LocalStorageService.initialize();

    // Initialize sync service
    _syncService = SyncService();

    // Load cached content timestamps
    await _loadContentTimestamps();

    // Listen for connectivity changes
    _connectivityService.connectionStatusStream
        .listen(_handleConnectivityChange);

    _initialized = true;
    debugPrint('OfflineManager: Initialized');

    // Update current status
    _updateStatus();
  }

  /// Load the timestamps of when content was last updated
  Future<void> _loadContentTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampsJson = prefs.getString('content_timestamps') ?? '{}';

      // Default to empty map if parsing fails
      try {
        final Map<String, dynamic> parsed = jsonDecode(timestampsJson);
        _contentLastUpdated = parsed.map(
          (key, value) => MapEntry(key, DateTime.parse(value)),
        );
      } catch (e) {
        debugPrint('OfflineManager: Error parsing timestamps: $e');
        _contentLastUpdated = {};
      }
    } catch (e) {
      debugPrint('OfflineManager: Error loading timestamps: $e');
      _contentLastUpdated = {};
    }
  }

  /// Save the timestamps of when content was last updated
  Future<void> _saveContentTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampsJson = jsonEncode(
        _contentLastUpdated.map(
          (key, value) => MapEntry(key, value.toIso8601String()),
        ),
      );
      await prefs.setString('content_timestamps', timestampsJson);
    } catch (e) {
      debugPrint('OfflineManager: Error saving timestamps: $e');
    }
  }

  /// Update the content timestamp for a specific content type
  Future<void> updateContentTimestamp(String contentType) async {
    _contentLastUpdated[contentType] = DateTime.now();
    await _saveContentTimestamps();
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(bool isOnline) {
    debugPrint(
        'OfflineManager: Connectivity changed to ${isOnline ? "online" : "offline"}');

    if (isOnline) {
      // When coming back online, trigger a sync
      _triggerSync();
    }

    // Update status
    _updateStatus();
  }

  /// Update the current offline status
  void _updateStatus() {
    final status = OfflineStatus(
      isOffline: !_connectivityService.isOnline,
      isSyncInProgress: _isSyncInProgress,
      lastSyncTimestamp: _getLastSyncTimestamp(),
      pendingSyncItems: _getPendingSyncItemCount(),
    );

    _statusController.add(status);
  }

  /// Get the last sync timestamp
  DateTime? _getLastSyncTimestamp() {
    try {
      final lastSyncStr = Hive.box(AppConstants.settingsBoxName)
          .get(AppConstants.lastSyncTimestampKey);
      if (lastSyncStr != null) {
        return DateTime.parse(lastSyncStr);
      }
    } catch (e) {
      debugPrint('OfflineManager: Error getting last sync timestamp: $e');
    }
    return null;
  }

  /// Get the number of pending sync items
  int _getPendingSyncItemCount() {
    try {
      if (Hive.isBoxOpen('sync_queue')) {
        return Hive.box('sync_queue').length;
      }
    } catch (e) {
      debugPrint('OfflineManager: Error getting pending sync items: $e');
    }
    return 0;
  }

  /// Trigger a sync operation
  Future<void> _triggerSync() async {
    if (_isSyncInProgress || !_connectivityService.isOnline) return;

    try {
      _isSyncInProgress = true;
      _updateStatus();

      await _syncService.performPeriodicSync();

      // Update last sync timestamp
      await Hive.box(AppConstants.settingsBoxName).put(
        AppConstants.lastSyncTimestampKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('OfflineManager: Sync error: $e');
    } finally {
      _isSyncInProgress = false;
      _updateStatus();
    }
  }

  /// Check if content needs to be refreshed
  bool shouldRefreshContent(String contentType, {Duration? maxAge}) {
    if (!_contentLastUpdated.containsKey(contentType)) {
      return true;
    }

    final lastUpdated = _contentLastUpdated[contentType]!;
    final now = DateTime.now();
    final age = now.difference(lastUpdated);

    // If maxAge is specified, use it, otherwise use default refresh strategy
    if (maxAge != null) {
      return age > maxAge;
    } else {
      // Default refresh strategy based on content type
      switch (contentType) {
        case 'bible':
          // Bible content rarely changes, refresh every 30 days
          return age.inDays > 30;
        case 'devotionals':
          // Devotionals might update daily
          return age.inHours > 24;
        case 'user_data':
          // User data should be fresh
          return age.inHours > 1;
        default:
          // Default to 12 hours
          return age.inHours > 12;
      }
    }
  }

  /// Manually trigger a sync operation
  Future<SyncResult> manualSync() async {
    if (!_connectivityService.isOnline) {
      return SyncResult(
        success: false,
        message: 'Device is offline',
        itemsSynced: 0,
      );
    }

    if (_isSyncInProgress) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        itemsSynced: 0,
      );
    }

    try {
      _isSyncInProgress = true;
      _updateStatus();

      final itemCount = _getPendingSyncItemCount();
      await _syncService.performPeriodicSync();

      // Update last sync timestamp
      final now = DateTime.now();
      await Hive.box(AppConstants.settingsBoxName).put(
        AppConstants.lastSyncTimestampKey,
        now.toIso8601String(),
      );

      return SyncResult(
        success: true,
        message: 'Sync completed successfully',
        itemsSynced: itemCount - _getPendingSyncItemCount(),
        timestamp: now,
      );
    } catch (e) {
      debugPrint('OfflineManager: Manual sync error: $e');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        itemsSynced: 0,
      );
    } finally {
      _isSyncInProgress = false;
      _updateStatus();
    }
  }

  /// Check if a specific content is available offline
  Future<bool> isContentAvailableOffline(
      String contentType, String contentId) async {
    switch (contentType) {
      case 'bible':
        final boxName = 'bible_verses_${contentId.replaceAll(':', '_')}';
        try {
          if (!Hive.isBoxOpen(boxName)) {
            await Hive.openBox(boxName);
          }
          return Hive.box(boxName).isNotEmpty;
        } catch (e) {
          debugPrint('OfflineManager: Error checking bible content: $e');
          return false;
        }

      case 'devotionals':
        try {
          if (!Hive.isBoxOpen('devotionals')) {
            await Hive.openBox('devotionals');
          }
          return Hive.box('devotionals').containsKey(contentId);
        } catch (e) {
          debugPrint('OfflineManager: Error checking devotional content: $e');
          return false;
        }

      default:
        return false;
    }
  }

  /// Clear all offline data (for debugging or user-triggered clear)
  Future<void> clearAllOfflineData() async {
    try {
      for (final boxName in _boxNames) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }
      _contentLastUpdated.clear();
      await _saveContentTimestamps();

      _updateStatus();
      debugPrint('OfflineManager: All offline data cleared');
    } catch (e) {
      debugPrint('OfflineManager: Error clearing offline data: $e');
    }
  }

  /// Cleanup old cache data to free up storage
  Future<void> cleanupOldCache() async {
    try {
      // Cleanup old bible content (keep only recently accessed)
      await _cleanupOldBibleContent();

      // Cleanup old devotionals (keep only recent ones)
      await _cleanupOldDevotionals();

      debugPrint('OfflineManager: Old cache cleaned up');
    } catch (e) {
      debugPrint('OfflineManager: Error cleaning up old cache: $e');
    }
  }

  /// Cleanup old Bible content
  Future<void> _cleanupOldBibleContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessHistoryJson = prefs.getString('bible_access_history') ?? '{}';
      final Map<String, dynamic> accessHistory = jsonDecode(accessHistoryJson);

      // Find all boxes in access history starting with "bible_verses_"
      final bibleBoxes = accessHistory.keys
          .where((boxName) => boxName.startsWith('bible_verses_'))
          .toList();

      // Sort by last access time
      bibleBoxes.sort((a, b) {
        final aTime = accessHistory[a] != null
            ? DateTime.parse(accessHistory[a]).millisecondsSinceEpoch
            : 0;
        final bTime = accessHistory[b] != null
            ? DateTime.parse(accessHistory[b]).millisecondsSinceEpoch
            : 0;
        return bTime.compareTo(aTime); // Newest first
      });

      // Keep the 20 most recently accessed boxes, delete the rest
      if (bibleBoxes.length > 20) {
        for (int i = 20; i < bibleBoxes.length; i++) {
          final boxName = bibleBoxes[i];
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).clear();
            await Hive.box(boxName).close();
          }
          await Hive.deleteBoxFromDisk(boxName);
          accessHistory.remove(boxName);
        }

        // Save updated access history
        await prefs.setString(
            'bible_access_history', jsonEncode(accessHistory));
      }
    } catch (e) {
      debugPrint('OfflineManager: Error cleaning up old Bible content: $e');
    }
  }

  /// Cleanup old devotionals
  Future<void> _cleanupOldDevotionals() async {
    try {
      if (!Hive.isBoxOpen('devotionals')) {
        await Hive.openBox('devotionals');
      }

      final devotionalsBox = Hive.box('devotionals');
      if (devotionalsBox.length <= 30) return; // Keep at least 30 devotionals

      // Get all devotionals sorted by date
      final allDevotionals = devotionalsBox.values.toList();
      allDevotionals.sort((a, b) {
        final aDate =
            a['date'] != null ? DateTime.parse(a['date']) : DateTime(1970);
        final bDate =
            b['date'] != null ? DateTime.parse(b['date']) : DateTime(1970);
        return bDate.compareTo(aDate); // Newest first
      });

      // Keep the 30 newest devotionals, delete the rest
      for (int i = 30; i < allDevotionals.length; i++) {
        final devotionalId = allDevotionals[i]['id'];
        if (devotionalId != null) {
          await devotionalsBox.delete(devotionalId);
        }
      }
    } catch (e) {
      debugPrint('OfflineManager: Error cleaning up old devotionals: $e');
    }
  }

  /// Record an access to a Bible content to update its access history
  Future<void> recordBibleAccess(
      String bookId, int chapterId, String version) async {
    try {
      final boxName = 'bible_verses_${version}_${bookId}_$chapterId';

      final prefs = await SharedPreferences.getInstance();
      final accessHistoryJson = prefs.getString('bible_access_history') ?? '{}';
      final Map<String, dynamic> accessHistory = jsonDecode(accessHistoryJson);

      // Update access time
      accessHistory[boxName] = DateTime.now().toIso8601String();

      // Save updated access history
      await prefs.setString('bible_access_history', jsonEncode(accessHistory));
    } catch (e) {
      debugPrint('OfflineManager: Error recording Bible access: $e');
    }
  }

  /// Dispose the offline manager
  void dispose() {
    _statusController.close();
  }

  // List of box names used by the application
  static const List<String> _boxNames = [
    'settings',
    'devotionals',
    'sync_queue',
    'offline_changes',
    'bookmarks',
    'highlights',
    'notes',
    'reading_history',
    'user_data',
  ];
}

/// Represents the current offline status
class OfflineStatus {
  final bool isOffline;
  final bool isSyncInProgress;
  final DateTime? lastSyncTimestamp;
  final int pendingSyncItems;

  OfflineStatus({
    required this.isOffline,
    required this.isSyncInProgress,
    this.lastSyncTimestamp,
    required this.pendingSyncItems,
  });

  String get statusMessage {
    if (isOffline) {
      return 'You are offline. Some features may be limited.';
    } else if (isSyncInProgress) {
      return 'Syncing your data...';
    } else if (pendingSyncItems > 0) {
      return '$pendingSyncItems items waiting to sync';
    } else {
      return 'All data is synced';
    }
  }

  String get lastSyncMessage {
    if (lastSyncTimestamp == null) {
      return 'Never synced';
    }

    final now = DateTime.now();
    final difference = now.difference(lastSyncTimestamp!);

    if (difference.inMinutes < 1) {
      return 'Synced just now';
    } else if (difference.inHours < 1) {
      return 'Synced ${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return 'Synced ${difference.inHours} hours ago';
    } else {
      return 'Synced ${difference.inDays} days ago';
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int itemsSynced;
  final DateTime? timestamp;

  SyncResult({
    required this.success,
    required this.message,
    required this.itemsSynced,
    this.timestamp,
  });
}
