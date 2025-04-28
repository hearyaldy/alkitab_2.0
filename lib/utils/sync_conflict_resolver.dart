// lib/utils/sync_conflict_resolver.dart

class SyncConflictResolver {
  /// Resolve conflicts between local and cloud data
  /// Provides strategies for merging or selecting the most appropriate data
  static Map<String, dynamic> resolveConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> cloudData,
  }) {
    // Determine which data is more recent
    final localTimestamp = _parseTimestamp(localData['timestamp']);
    final cloudTimestamp = _parseTimestamp(cloudData['timestamp']);

    // Prefer the most recent data
    if (localTimestamp.isAfter(cloudTimestamp)) {
      return localData;
    } else if (cloudTimestamp.isAfter(localTimestamp)) {
      return cloudData;
    }

    // If timestamps are equal, merge the data
    return _mergeData(localData, cloudData);
  }

  /// Parse timestamp safely
  static DateTime _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is DateTime) {
        return timestamp;
      }
      // Fallback to current time if parsing fails
      return DateTime.now();
    } catch (e) {
      print('Timestamp parsing error: $e');
      return DateTime.now();
    }
  }

  /// Merge two data maps intelligently
  static Map<String, dynamic> _mergeData(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    final mergedData = Map<String, dynamic>.from(localData);

    cloudData.forEach((key, value) {
      // If local data doesn't have the key or cloud data is non-null
      if (!mergedData.containsKey(key) || value != null) {
        mergedData[key] = value;
      }
    });

    return mergedData;
  }

  /// Resolve list-based conflicts
  static List<dynamic> resolveListConflict(
    List<dynamic> localList,
    List<dynamic> cloudList,
  ) {
    // Remove duplicates
    final mergedSet = {...localList, ...cloudList};

    // Optional: Sort if needed
    // Implement sorting logic based on your requirements
    return mergedSet.toList();
  }

  /// Special resolver for specific data types
  static dynamic resolveSpecificTypeConflict(
    dynamic localValue,
    dynamic cloudValue,
    String dataType,
  ) {
    switch (dataType) {
      case 'bookmarks':
        // Custom logic for bookmark conflicts
        return _mergeLists(localValue, cloudValue);
      case 'settings':
        // Prefer cloud settings unless local has explicit override
        return cloudValue;
      case 'reading_progress':
        // Take the most advanced progress
        return _resolveBestProgress(localValue, cloudValue);
      default:
        // Default to cloud value
        return cloudValue ?? localValue;
    }
  }

  /// Merge two lists, removing duplicates
  static List<dynamic> _mergeLists(List<dynamic>? local, List<dynamic>? cloud) {
    if (local == null) return cloud ?? [];
    if (cloud == null) return local;

    final mergedSet = {...local, ...cloud};
    return mergedSet.toList();
  }

  /// Resolve reading progress by taking the most advanced
  static dynamic _resolveBestProgress(dynamic local, dynamic cloud) {
    // Implement logic to determine the most advanced reading progress
    // This could involve comparing chapter, percentage, or timestamp
    return cloud; // Placeholder
  }
}
