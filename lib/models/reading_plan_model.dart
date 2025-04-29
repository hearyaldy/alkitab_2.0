// lib/models/reading_plan_model.dart
import 'package:hive/hive.dart';

part 'reading_plan_model.g.dart'; // Will be generated with build_runner

// Model for Bible Reading Plan
@HiveType(typeId: 5)
class ReadingPlanModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int durationDays;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final List<ReadingPlanDayModel> days;

  @HiveField(6)
  final bool isSynced;

  ReadingPlanModel({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    this.imageUrl,
    required this.days,
    this.isSynced = false,
  });

  factory ReadingPlanModel.fromJson(Map<String, dynamic> json) {
    List<ReadingPlanDayModel> daysList = [];
    if (json['days'] != null) {
      daysList = (json['days'] as List)
          .map((day) => ReadingPlanDayModel.fromJson(day))
          .toList();
    }

    return ReadingPlanModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      durationDays: json['duration_days'] ?? 0,
      imageUrl: json['image_url'],
      days: daysList,
      isSynced: json['is_synced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'duration_days': durationDays,
      'image_url': imageUrl,
      'days': days.map((day) => day.toJson()).toList(),
      'is_synced': isSynced,
    };
  }

  // Create a copy with updated fields
  ReadingPlanModel copyWith({
    String? id,
    String? title,
    String? description,
    int? durationDays,
    String? imageUrl,
    List<ReadingPlanDayModel>? days,
    bool? isSynced,
  }) {
    return ReadingPlanModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationDays: durationDays ?? this.durationDays,
      imageUrl: imageUrl ?? this.imageUrl,
      days: days ?? this.days,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

// Model for a single day in a reading plan
@HiveType(typeId: 6)
class ReadingPlanDayModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String planId;

  @HiveField(2)
  final int dayNumber;

  @HiveField(3)
  final List<String> scriptureReferences;

  @HiveField(4)
  final String title;

  @HiveField(5)
  final String? description;

  ReadingPlanDayModel({
    required this.id,
    required this.planId,
    required this.dayNumber,
    required this.scriptureReferences,
    required this.title,
    this.description,
  });

  factory ReadingPlanDayModel.fromJson(Map<String, dynamic> json) {
    List<String> references = [];
    if (json['scripture_references'] != null) {
      if (json['scripture_references'] is List) {
        references = (json['scripture_references'] as List)
            .map((ref) => ref.toString())
            .toList();
      } else if (json['scripture_references'] is String) {
        try {
          // Try to parse if it's a JSON string
          final parsedRefs = json['scripture_references'];
          if (parsedRefs is List) {
            references = parsedRefs.map((ref) => ref.toString()).toList();
          }
        } catch (_) {
          // If parsing fails, use the string as a single reference
          references = [json['scripture_references'].toString()];
        }
      }
    }

    return ReadingPlanDayModel(
      id: json['id'] ?? '',
      planId: json['reading_plan_id'] ?? '',
      dayNumber: json['day_number'] ?? 0,
      scriptureReferences: references,
      title: json['title'] ?? 'Day Reading',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reading_plan_id': planId,
      'day_number': dayNumber,
      'scripture_references': scriptureReferences,
      'title': title,
      'description': description,
    };
  }
}

// Model to track a user's progress in a reading plan
@HiveType(typeId: 7)
class UserReadingPlanModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String readingPlanId;

  @HiveField(3)
  final DateTime startDate;

  @HiveField(4)
  final int currentDay;

  @HiveField(5)
  final bool isCompleted;

  @HiveField(6)
  final DateTime? completionDate;

  @HiveField(7)
  final List<int> completedDays;

  @HiveField(8)
  final bool isSynced;

  UserReadingPlanModel({
    required this.id,
    required this.userId,
    required this.readingPlanId,
    required this.startDate,
    required this.currentDay,
    required this.isCompleted,
    this.completionDate,
    required this.completedDays,
    this.isSynced = false,
  });

  factory UserReadingPlanModel.fromJson(Map<String, dynamic> json) {
    List<int> completedDaysList = [];
    if (json['completed_days'] != null) {
      completedDaysList = (json['completed_days'] as List)
          .map((day) => int.tryParse(day.toString()) ?? 0)
          .toList();
    }

    return UserReadingPlanModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      readingPlanId: json['reading_plan_id'] ?? '',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      currentDay: json['current_day'] ?? 1,
      isCompleted: json['is_completed'] ?? false,
      completionDate: json['completion_date'] != null
          ? DateTime.parse(json['completion_date'])
          : null,
      completedDays: completedDaysList,
      isSynced: json['is_synced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'reading_plan_id': readingPlanId,
      'start_date': startDate.toIso8601String(),
      'current_day': currentDay,
      'is_completed': isCompleted,
      'completion_date': completionDate?.toIso8601String(),
      'completed_days': completedDays,
      'is_synced': isSynced,
    };
  }

  // Create a copy with updated fields
  UserReadingPlanModel copyWith({
    String? id,
    String? userId,
    String? readingPlanId,
    DateTime? startDate,
    int? currentDay,
    bool? isCompleted,
    DateTime? completionDate,
    List<int>? completedDays,
    bool? isSynced,
  }) {
    return UserReadingPlanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      readingPlanId: readingPlanId ?? this.readingPlanId,
      startDate: startDate ?? this.startDate,
      currentDay: currentDay ?? this.currentDay,
      isCompleted: isCompleted ?? this.isCompleted,
      completionDate: completionDate ?? this.completionDate,
      completedDays: completedDays ?? this.completedDays,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Calculate progress percentage
  double getProgressPercentage(int totalDays) {
    if (totalDays <= 0) return 0.0;
    return completedDays.length / totalDays;
  }

  // Check if a specific day is completed
  bool isDayCompleted(int dayNumber) {
    return completedDays.contains(dayNumber);
  }

  // Mark a day as completed
  UserReadingPlanModel markDayAsCompleted(int dayNumber) {
    if (!completedDays.contains(dayNumber)) {
      final newCompletedDays = List<int>.from(completedDays)..add(dayNumber);
      return copyWith(
        completedDays: newCompletedDays,
        currentDay: dayNumber + 1,
        isSynced: false,
      );
    }
    return this;
  }
}
