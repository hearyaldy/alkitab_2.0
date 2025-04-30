// lib/utils/sync_conflict_resolver.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';

class SyncConflictResolver {
  /// Resolve conflicts between local and cloud data
  /// Provides strategies for merging or selecting the most appropriate data
  static Map<String, dynamic> resolveConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> cloudData,
    String dataType = 'generic',
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.mostRecent,
  }) {
    // First, apply data type-specific resolution if available
    if (dataType != 'generic') {
      final resolvedData = _resolveByDataType(localData, cloudData, dataType);
      if (resolvedData != null) {
        return resolvedData;
      }
    }

    // If no data type-specific resolution or it returned null, use the general strategy
    switch (strategy) {
      case ConflictResolutionStrategy.mostRecent:
        return _resolveByTimestamp(localData, cloudData);
      case ConflictResolutionStrategy.localPriority:
        return Map<String, dynamic>.from(localData);
      case ConflictResolutionStrategy.cloudPriority:
        return Map<String, dynamic>.from(cloudData);
      case ConflictResolutionStrategy.smartMerge:
      default:
        return _smartMergeData(localData, cloudData, dataType);
    }
  }

  /// Resolve conflict by timestamp - most recent wins
  static Map<String, dynamic> _resolveByTimestamp(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    final localTimestamp = _extractTimestamp(localData);
    final cloudTimestamp = _extractTimestamp(cloudData);

    // If we can determine timestamps, prefer the most recent
    if (localTimestamp != null && cloudTimestamp != null) {
      if (localTimestamp.isAfter(cloudTimestamp)) {
        return localData;
      } else if (cloudTimestamp.isAfter(localTimestamp)) {
        return cloudData;
      }
    }

    // If timestamps are equal or can't be determined, fall back to smart merge
    return _smartMergeData(localData, cloudData);
  }

  /// Extract timestamp from data in various formats
  static DateTime? _extractTimestamp(Map<String, dynamic> data) {
    // Check for common timestamp field names
    final timestampFields = [
      'timestamp',
      'updated_at',
      'last_modified',
      'modified_at',
      'created_at',
      'date'
    ];

    for (final field in timestampFields) {
      if (data.containsKey(field) && data[field] != null) {
        return _parseTimestamp(data[field]);
      }
    }

    return null;
  }

  /// Parse timestamp safely from various formats
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('SyncConflictResolver: Timestamp parsing error: $e');
    }
    return null;
  }

  /// Smart merge of two data maps with field-level resolution
  static Map<String, dynamic> _smartMergeData(
      Map<String, dynamic> localData, Map<String, dynamic> cloudData,
      [String dataType = 'generic']) {
    final result = Map<String, dynamic>.from(localData);

    // First pass: add all fields that only exist in cloud data
    cloudData.forEach((key, cloudValue) {
      if (!result.containsKey(key)) {
        result[key] = cloudValue;
      }
    });

    // Second pass: handle conflicts for fields that exist in both
    cloudData.forEach((key, cloudValue) {
      if (result.containsKey(key)) {
        final localValue = result[key];

        // Skip if values are identical
        if (_areValuesIdentical(localValue, cloudValue)) {
          return;
        }

        // Resolve based on the field type
        if (localValue is Map && cloudValue is Map) {
          // Recursively merge nested maps
          result[key] = _smartMergeData(Map<String, dynamic>.from(localValue),
              Map<String, dynamic>.from(cloudValue));
        } else if (localValue is List && cloudValue is List) {
          // Merge lists, handling potential duplicates
          result[key] =
              _mergeListsSmartly(localValue, cloudValue, key, dataType);
        } else if (key.contains('timestamp') ||
            key.contains('updated_at') ||
            key.contains('modified_at')) {
          // For timestamp fields, take the most recent
          final localTime = _parseTimestamp(localValue);
          final cloudTime = _parseTimestamp(cloudValue);

          if (localTime != null && cloudTime != null) {
            result[key] =
                localTime.isAfter(cloudTime) ? localValue : cloudValue;
          } else {
            // If can't parse, prefer cloud value
            result[key] = cloudValue;
          }
        } else {
          // For other fields:
          // - Prefer non-null values
          // - For strings, prefer non-empty strings
          // - Otherwise, prefer cloud value (as it's likely more canonical)
          if (cloudValue == null && localValue != null) {
            // Keep local non-null value
          } else if (cloudValue is String &&
              (cloudValue).isEmpty &&
              localValue is String &&
              (localValue).isNotEmpty) {
            // Keep local non-empty string
          } else {
            // Default to cloud value
            result[key] = cloudValue;
          }
        }
      }
    });

    return result;
  }

  /// Check if two values are identical, handling special cases
  static bool _areValuesIdentical(dynamic value1, dynamic value2) {
    if (value1 == value2) return true;

    // Handle special cases
    if (value1 is String && value2 is String) {
      return value1.trim() == value2.trim();
    }

    if (value1 is Map && value2 is Map) {
      if (value1.length != value2.length) return false;
      for (final key in value1.keys) {
        if (!value2.containsKey(key) ||
            !_areValuesIdentical(value1[key], value2[key])) {
          return false;
        }
      }
      return true;
    }

    if (value1 is List && value2 is List) {
      if (value1.length != value2.length) return false;
      for (int i = 0; i < value1.length; i++) {
        if (!_areValuesIdentical(value1[i], value2[i])) {
          return false;
        }
      }
      return true;
    }

    // Convert values to string and compare (handles cases like int vs double)
    try {
      return value1.toString() == value2.toString();
    } catch (_) {
      return false;
    }
  }

  /// Smart merge of lists with duplicate detection and better ordering
  static List<dynamic> _mergeListsSmartly(
    List<dynamic> localList,
    List<dynamic> cloudList,
    String fieldName,
    String dataType,
  ) {
    // For empty lists, prefer the non-empty one
    if (localList.isEmpty) return cloudList;
    if (cloudList.isEmpty) return localList;

    // If lists contain maps with IDs, merge by ID
    if (localList.isNotEmpty &&
        localList.first is Map &&
        cloudList.isNotEmpty &&
        cloudList.first is Map) {
      return _mergeListsOfMaps(localList, cloudList);
    }

    // If lists contain primitive values, check for duplicates
    final Set<dynamic> mergedSet = {};

    // Determine how to compare items (needed for non-primitive types)
    final compareFunction = _getComparisonFunction(dataType, fieldName);

    // Add all items, using our custom equality if provided
    for (final item in [...cloudList, ...localList]) {
      bool isDuplicate = false;

      if (compareFunction != null) {
        // Custom comparison
        for (final existing in mergedSet) {
          if (compareFunction(existing, item)) {
            isDuplicate = true;
            break;
          }
        }
      } else {
        // Standard equality for primitive values
        isDuplicate = mergedSet.contains(item);
      }

      if (!isDuplicate) {
        mergedSet.add(item);
      }
    }

    // Convert back to list
    final result = mergedSet.toList();

    // Sort if possible and appropriate
    _sortListIfPossible(result, fieldName, dataType);

    return result;
  }

  /// Merge lists of maps, handling ID-based deduplication
  static List<dynamic> _mergeListsOfMaps(
    List<dynamic> localList,
    List<dynamic> cloudList,
  ) {
    // Create a map of ID -> value for fast lookup
    final Map<String, dynamic> resultMap = {};

    // Identify potential ID fields
    final idFields = _findPotentialIdFields(localList);
    if (idFields.isEmpty) {
      // If no ID field found, fall back to simple merge with object equality
      return [
        ...{...cloudList, ...localList}
      ];
    }

    // First pass: add all cloud items
    for (final item in cloudList) {
      final id = _extractId(item, idFields);
      if (id != null) {
        resultMap[id] = item;
      } else {
        // Items without ID are always kept
        resultMap['cloud_${cloudList.indexOf(item)}'] = item;
      }
    }

    // Second pass: add or update with local items
    for (final item in localList) {
      final id = _extractId(item, idFields);
      if (id != null) {
        // If item exists in both, merge the maps
        if (resultMap.containsKey(id)) {
          resultMap[id] = _smartMergeData(Map<String, dynamic>.from(item),
              Map<String, dynamic>.from(resultMap[id]));
        } else {
          resultMap[id] = item;
        }
      } else {
        // Items without ID are always kept
        resultMap['local_${localList.indexOf(item)}'] = item;
      }
    }

    return resultMap.values.toList();
  }

  /// Find potential ID fields in a list of maps
  static List<String> _findPotentialIdFields(List<dynamic> items) {
    // Most commonly used ID field names
    final commonIdFields = ['id', 'ID', '_id', 'uid', 'key', 'uuid'];

    // If the list is empty or items aren't maps, return empty list
    if (items.isEmpty || items.first is! Map) {
      return [];
    }

    final Map<String, dynamic> firstItem = items.first;
    final potentialFields = <String>[];

    // First, check common field names
    for (final field in commonIdFields) {
      if (firstItem.containsKey(field)) {
        potentialFields.add(field);
      }
    }

    // If no common fields found, look for fields with "id" in their name
    if (potentialFields.isEmpty) {
      for (final field in firstItem.keys) {
        if (field.toLowerCase().contains('id') &&
            field.toLowerCase() != 'hide') {
          potentialFields.add(field);
        }
      }
    }

    return potentialFields;
  }

  /// Extract ID from an item given potential ID fields
  static String? _extractId(dynamic item, List<String> idFields) {
    if (item is! Map) return null;

    for (final field in idFields) {
      if (item.containsKey(field) && item[field] != null) {
        return item[field].toString();
      }
    }

    return null;
  }

  /// Get a comparison function for a specific data type and field
  static bool Function(dynamic, dynamic)? _getComparisonFunction(
    String dataType,
    String fieldName,
  ) {
    // Custom comparison for specific data types
    if (dataType == 'bookmarks') {
      return (a, b) {
        if (a is Map && b is Map) {
          // Compare by reference for bookmarks
          if (a.containsKey('verse_reference') &&
              b.containsKey('verse_reference')) {
            return a['verse_reference'] == b['verse_reference'];
          }
        }
        return a == b;
      };
    } else if (dataType == 'highlights') {
      return (a, b) {
        if (a is Map && b is Map) {
          // Compare by verse for highlights
          return a['book_id'] == b['book_id'] &&
              a['chapter_id'] == b['chapter_id'] &&
              a['verse_id'] == b['verse_id'];
        }
        return a == b;
      };
    } else if (dataType == 'notes') {
      return (a, b) {
        if (a is Map && b is Map) {
          // Compare by reference for notes
          return a['book_id'] == b['book_id'] &&
              a['chapter_id'] == b['chapter_id'] &&
              a['verse_id'] == b['verse_id'];
        }
        return a == b;
      };
    } else if (fieldName.contains('reading_plan')) {
      return (a, b) {
        if (a is Map && b is Map) {
          // Compare by reading plan ID and day
          return a['reading_plan_id'] == b['reading_plan_id'] &&
              a['day_number'] == b['day_number'];
        }
        return a == b;
      };
    }

    // Default: use standard equality
    return null;
  }

  /// Sort a list if possible based on data type
  static void _sortListIfPossible(
    List<dynamic> list,
    String fieldName,
    String dataType,
  ) {
    // Don't attempt to sort empty or single-item lists
    if (list.length <= 1) return;

    try {
      if (list.first is num) {
        // Sort numbers numerically
        list.sort();
      } else if (list.first is String) {
        // Sort strings alphabetically
        list.sort();
      } else if (list.first is DateTime) {
        // Sort dates chronologically
        list.sort((a, b) => (a as DateTime).compareTo(b as DateTime));
      } else if (list.first is Map) {
        // Sort maps by a relevant field based on data type
        if (dataType == 'bookmarks' ||
            dataType == 'notes' ||
            dataType == 'highlights') {
          // Sort by creation date, most recent first
          list.sort((a, b) {
            final aDate = _parseTimestamp(a['created_at'] ?? a['date_created']);
            final bDate = _parseTimestamp(b['created_at'] ?? b['date_created']);

            if (aDate != null && bDate != null) {
              return bDate.compareTo(aDate); // Descending order
            }
            return 0;
          });
        } else if (dataType == 'reading_plan') {
          // Sort by day number
          list.sort((a, b) {
            final aDay = a['day_number'] as int?;
            final bDay = b['day_number'] as int?;

            if (aDay != null && bDay != null) {
              return aDay.compareTo(bDay); // Ascending order
            }
            return 0;
          });
        }
      }
    } catch (e) {
      // If sorting fails, leave the list as is
      debugPrint('SyncConflictResolver: Sorting error: $e');
    }
  }

  /// Resolve conflicts for specific data types
  static Map<String, dynamic>? _resolveByDataType(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
    String dataType,
  ) {
    switch (dataType) {
      case 'bookmarks':
        return _resolveBookmarkConflict(localData, cloudData);
      case 'notes':
        return _resolveNoteConflict(localData, cloudData);
      case 'highlights':
        return _resolveHighlightConflict(localData, cloudData);
      case 'reading_progress':
        return _resolveReadingProgressConflict(localData, cloudData);
      case 'reading_plan':
        return _resolveReadingPlanConflict(localData, cloudData);
      case 'settings':
        return _resolveSettingsConflict(localData, cloudData);
      case 'user_profile':
        return _resolveUserProfileConflict(localData, cloudData);
      default:
        return null; // Use general strategy
    }
  }

  /// Resolve bookmark conflicts
  static Map<String, dynamic> _resolveBookmarkConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For bookmarks, we prefer the version that has more content
    // If cloud has more fields filled out, prefer it
    if (localData['notes'] == null && cloudData['notes'] != null) {
      return cloudData;
    }

    // If local has more fields filled out, prefer it
    if (localData['notes'] != null && cloudData['notes'] == null) {
      return localData;
    }

    // If both have notes, prefer the one with the longer content
    if (localData['notes'] != null && cloudData['notes'] != null) {
      if ((localData['notes'] as String).length >
          (cloudData['notes'] as String).length) {
        return localData;
      } else {
        return cloudData;
      }
    }

    // If neither has notes, use timestamp based resolution
    return _resolveByTimestamp(localData, cloudData);
  }

  /// Resolve note conflicts
  static Map<String, dynamic> _resolveNoteConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For notes, check for different content and merge if needed
    final localContent = localData['content'] ?? localData['note_text'] ?? '';
    final cloudContent = cloudData['content'] ?? cloudData['note_text'] ?? '';

    // If content is identical, use timestamp to resolve other fields
    if (localContent == cloudContent) {
      return _resolveByTimestamp(localData, cloudData);
    }

    // If one is empty, prefer the non-empty one
    if (localContent.isEmpty && cloudContent.isNotEmpty) {
      return cloudData;
    } else if (localContent.isNotEmpty && cloudContent.isEmpty) {
      return localData;
    }

    // Merge the contents if they're different and both non-empty
    final result = Map<String, dynamic>.from(cloudData);
    final localTimestamp = _extractTimestamp(localData);
    final cloudTimestamp = _extractTimestamp(cloudData);

    // Decide which is newer
    bool isLocalNewer = false;
    if (localTimestamp != null && cloudTimestamp != null) {
      isLocalNewer = localTimestamp.isAfter(cloudTimestamp);
    }

    // Merge the contents, with the newer version first
    final mergedContent = isLocalNewer
        ? '$localContent\n\n[Older version:]\n$cloudContent'
        : '$cloudContent\n\n[Older version:]\n$localContent';

    result['content'] = mergedContent;
    result['note_text'] = mergedContent;
    result['last_modified'] = DateTime.now().toIso8601String();

    // Set a flag to indicate this was merged
    result['was_merged'] = true;

    return result;
  }

  /// Resolve highlight conflicts
  static Map<String, dynamic> _resolveHighlightConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For highlights, prefer the newer one as it might have a different color
    return _resolveByTimestamp(localData, cloudData);
  }

  /// Resolve reading progress conflicts
  static Map<String, dynamic> _resolveReadingProgressConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For reading progress, take the highest progress value
    final localProgress = _extractProgress(localData);
    final cloudProgress = _extractProgress(cloudData);

    if (localProgress > cloudProgress) {
      return localData;
    } else {
      return cloudData;
    }
  }

  /// Extract progress value from data
  static double _extractProgress(Map<String, dynamic> data) {
    // Try various progress fields
    if (data.containsKey('progress') && data['progress'] is num) {
      return (data['progress'] as num).toDouble();
    }

    if (data.containsKey('percentage') && data['percentage'] is num) {
      return (data['percentage'] as num).toDouble();
    }

    // Extract from chapter/verse info if available
    if (data.containsKey('current_chapter') &&
        data.containsKey('total_chapters')) {
      final current = data['current_chapter'] as int? ?? 0;
      final total = data['total_chapters'] as int? ?? 1;
      return current / total;
    }

    // Default to 0 if no progress info found
    return 0.0;
  }

  /// Resolve reading plan conflicts
  static Map<String, dynamic> _resolveReadingPlanConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For reading plans, take the version with more completed days
    final localCompletedDays = _extractCompletedDays(localData);
    final cloudCompletedDays = _extractCompletedDays(cloudData);

    if (localCompletedDays.length > cloudCompletedDays.length) {
      return localData;
    } else if (cloudCompletedDays.length > localCompletedDays.length) {
      return cloudData;
    }

    // If same number of completed days, merge them
    final allCompletedDays =
        <int>{...localCompletedDays, ...cloudCompletedDays}.toList();
    allCompletedDays.sort();

    final result = Map<String, dynamic>.from(cloudData);
    result['completed_days'] = allCompletedDays;
    result['current_day'] =
        allCompletedDays.isEmpty ? 1 : allCompletedDays.last + 1;

    return result;
  }

  /// Extract completed days from reading plan data
  static List<int> _extractCompletedDays(Map<String, dynamic> data) {
    if (data.containsKey('completed_days')) {
      if (data['completed_days'] is List) {
        return (data['completed_days'] as List)
            .map((day) => day is int ? day : int.tryParse(day.toString()) ?? 0)
            .toList()
            .cast<int>();
      } else if (data['completed_days'] is String) {
        // Try to parse JSON string
        try {
          final decoded = jsonDecode(data['completed_days'] as String);
          if (decoded is List) {
            return decoded
                .map((day) =>
                    day is int ? day : int.tryParse(day.toString()) ?? 0)
                .toList()
                .cast<int>();
          }
        } catch (_) {}
      }
    }

    return [];
  }

  /// Resolve settings conflicts
  static Map<String, dynamic> _resolveSettingsConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For settings, we use a field-by-field approach with user preferences taking priority

    // Start with cloud data as base
    final result = Map<String, dynamic>.from(cloudData);

    // Override with local preferences if they exist
    localData.forEach((key, value) {
      // Skip metadata fields
      if (key == 'id' || key == 'user_id' || key.contains('timestamp')) {
        return;
      }

      // Override cloud value if local has explicit preference
      if (value != null && key.contains('preference')) {
        result[key] = value;
      }
    });

    return result;
  }

  /// Resolve user profile conflicts
  static Map<String, dynamic> _resolveUserProfileConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    // For user profiles, prefer cloud data for auth fields,
    // but local data for customization fields
    final result = Map<String, dynamic>.from(cloudData);

    // Use local values for customization fields
    final customizationFields = [
      'display_name',
      'preferred_bible_version',
      'theme',
      'font_size',
      'profile_photo_url'
    ];

    for (final field in customizationFields) {
      if (localData.containsKey(field) && localData[field] != null) {
        result[field] = localData[field];
      }
    }

    return result;
  }
}

/// Enum for conflict resolution strategies
enum ConflictResolutionStrategy {
  /// Use the most recently updated version
  mostRecent,

  /// Always prefer local data
  localPriority,

  /// Always prefer cloud data
  cloudPriority,

  /// Intelligently merge data
  smartMerge,
}
