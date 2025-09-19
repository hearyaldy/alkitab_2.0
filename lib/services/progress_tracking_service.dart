import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../models/devotional_model.dart';

class ProgressTrackingService {
  static final ProgressTrackingService _instance = ProgressTrackingService._internal();
  factory ProgressTrackingService() => _instance;
  ProgressTrackingService._internal();

  static const String _progressBoxName = 'user_progress';
  static const String _lastReadDateKey = 'last_read_date';
  static const String _readingStreakKey = 'reading_streak';
  static const String _totalDevotionalsReadKey = 'total_devotionals_read';
  static const String _readDevotionalsKey = 'read_devotionals';
  static const String _weeklyGoalKey = 'weekly_goal';
  static const String _monthlyStatsKey = 'monthly_stats';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize the progress tracking service
  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_progressBoxName)) {
      await Hive.openBox(_progressBoxName);
    }
  }

  // Mark a devotional as read
  Future<void> markDevotionalAsRead(DevotionalModel devotional) async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    final user = AuthService.currentUser;

    if (user == null) return;

    final today = DateTime.now();

    // Get current progress data
    final readDevotionals = await getReadDevotionals();
    final devotionalId = devotional.id ?? devotional.title;

    // Check if already read today
    if (readDevotionals.contains(devotionalId)) {
      return; // Already marked as read
    }

    // Add to read devotionals
    readDevotionals.add(devotionalId);
    await box.put(_readDevotionalsKey, readDevotionals);

    // Update reading streak
    await _updateReadingStreak();

    // Update total count
    final totalRead = await getTotalDevotionalsRead();
    await box.put(_totalDevotionalsReadKey, totalRead + 1);

    // Update monthly stats
    await _updateMonthlyStats();

    // Sync to cloud if online
    await _syncProgressToCloud();

    debugPrint('Devotional marked as read: $devotionalId');
  }

  // Get current reading streak
  Future<int> getReadingStreak() async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    return box.get(_readingStreakKey, defaultValue: 0);
  }

  // Get total devotionals read
  Future<int> getTotalDevotionalsRead() async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    return box.get(_totalDevotionalsReadKey, defaultValue: 0);
  }

  // Get list of read devotionals
  Future<List<String>> getReadDevotionals() async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    final readList = box.get(_readDevotionalsKey, defaultValue: <String>[]);
    return List<String>.from(readList);
  }

  // Check if devotional was read
  Future<bool> isDevotionalRead(String devotionalId) async {
    final readDevotionals = await getReadDevotionals();
    return readDevotionals.contains(devotionalId);
  }

  // Get weekly goal
  Future<int> getWeeklyGoal() async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    return box.get(_weeklyGoalKey, defaultValue: 7); // Default 7 days per week
  }

  // Set weekly goal
  Future<void> setWeeklyGoal(int goal) async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    await box.put(_weeklyGoalKey, goal);
    await _syncProgressToCloud();
  }

  // Get weekly progress
  Future<WeeklyProgress> getWeeklyProgress() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final readDevotionals = await getReadDevotionals();
    final weeklyGoal = await getWeeklyGoal();

    int daysRead = 0;
    for (int i = 0; i < 7; i++) {
      // Check if any devotional was read on this day
      // This is a simplified check; you might want to store read dates more precisely
      if (readDevotionals.isNotEmpty) {
        daysRead++; // Simplified for now
      }
    }

    return WeeklyProgress(
      daysRead: daysRead,
      goal: weeklyGoal,
      startDate: startOfWeek,
    );
  }

  // Get monthly stats
  Future<MonthlyStats> getMonthlyStats() async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    final statsJson = box.get(_monthlyStatsKey, defaultValue: '{}');
    final statsMap = jsonDecode(statsJson) as Map<String, dynamic>;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthData = statsMap[monthKey] ?? {
      'devotionalsRead': 0,
      'daysActive': 0,
      'longestStreak': 0,
    };

    return MonthlyStats(
      month: now.month,
      year: now.year,
      devotionalsRead: monthData['devotionalsRead'] ?? 0,
      daysActive: monthData['daysActive'] ?? 0,
      longestStreak: monthData['longestStreak'] ?? 0,
    );
  }

  // Get progress summary
  Future<ProgressSummary> getProgressSummary() async {
    final streak = await getReadingStreak();
    final totalRead = await getTotalDevotionalsRead();
    final weeklyProgress = await getWeeklyProgress();
    final monthlyStats = await getMonthlyStats();

    return ProgressSummary(
      currentStreak: streak,
      totalDevotionalsRead: totalRead,
      weeklyProgress: weeklyProgress,
      monthlyStats: monthlyStats,
    );
  }

  // Reset progress (for testing or user request)
  Future<void> resetProgress() async {
    await initialize();
    final box = Hive.box(_progressBoxName);
    await box.clear();
    await _syncProgressToCloud();
    debugPrint('Progress reset');
  }

  // Private methods

  Future<void> _updateReadingStreak() async {
    final box = Hive.box(_progressBoxName);
    final today = DateTime.now();
    final todayString = _formatDate(today);
    final lastReadDate = box.get(_lastReadDateKey);

    if (lastReadDate == null) {
      // First time reading
      await box.put(_readingStreakKey, 1);
      await box.put(_lastReadDateKey, todayString);
      return;
    }

    final lastRead = DateTime.parse(lastReadDate);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_formatDate(lastRead) == _formatDate(yesterday)) {
      // Consecutive day
      final currentStreak = await getReadingStreak();
      await box.put(_readingStreakKey, currentStreak + 1);
    } else if (_formatDate(lastRead) != todayString) {
      // Streak broken
      await box.put(_readingStreakKey, 1);
    }

    await box.put(_lastReadDateKey, todayString);
  }

  Future<void> _updateMonthlyStats() async {
    final box = Hive.box(_progressBoxName);
    final statsJson = box.get(_monthlyStatsKey, defaultValue: '{}');
    final statsMap = jsonDecode(statsJson) as Map<String, dynamic>;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthData = Map<String, dynamic>.from(statsMap[monthKey] ?? {
      'devotionalsRead': 0,
      'daysActive': 0,
      'longestStreak': 0,
    });

    monthData['devotionalsRead'] = (monthData['devotionalsRead'] ?? 0) + 1;

    final currentStreak = await getReadingStreak();
    if (currentStreak > (monthData['longestStreak'] ?? 0)) {
      monthData['longestStreak'] = currentStreak;
    }

    statsMap[monthKey] = monthData;
    await box.put(_monthlyStatsKey, jsonEncode(statsMap));
  }

  Future<void> _syncProgressToCloud() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final progressData = {
        'reading_streak': await getReadingStreak(),
        'total_devotionals_read': await getTotalDevotionalsRead(),
        'read_devotionals': await getReadDevotionals(),
        'weekly_goal': await getWeeklyGoal(),
        'last_updated': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('user_progress')
          .doc(user.uid)
          .set(progressData, SetOptions(merge: true));

      debugPrint('Progress synced to cloud');
    } catch (e) {
      debugPrint('Failed to sync progress to cloud: $e');
    }
  }

  // Sync progress from cloud
  Future<void> syncProgressFromCloud() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('user_progress')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final box = Hive.box(_progressBoxName);

        await box.put(_readingStreakKey, data['reading_streak'] ?? 0);
        await box.put(_totalDevotionalsReadKey, data['total_devotionals_read'] ?? 0);
        await box.put(_readDevotionalsKey, data['read_devotionals'] ?? <String>[]);
        await box.put(_weeklyGoalKey, data['weekly_goal'] ?? 7);

        debugPrint('Progress synced from cloud');
      }
    } catch (e) {
      debugPrint('Failed to sync progress from cloud: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Data models
class WeeklyProgress {
  final int daysRead;
  final int goal;
  final DateTime startDate;

  WeeklyProgress({
    required this.daysRead,
    required this.goal,
    required this.startDate,
  });

  double get percentage => goal > 0 ? (daysRead / goal).clamp(0.0, 1.0) : 0.0;
  bool get isGoalMet => daysRead >= goal;
}

class MonthlyStats {
  final int month;
  final int year;
  final int devotionalsRead;
  final int daysActive;
  final int longestStreak;

  MonthlyStats({
    required this.month,
    required this.year,
    required this.devotionalsRead,
    required this.daysActive,
    required this.longestStreak,
  });
}

class ProgressSummary {
  final int currentStreak;
  final int totalDevotionalsRead;
  final WeeklyProgress weeklyProgress;
  final MonthlyStats monthlyStats;

  ProgressSummary({
    required this.currentStreak,
    required this.totalDevotionalsRead,
    required this.weeklyProgress,
    required this.monthlyStats,
  });
}