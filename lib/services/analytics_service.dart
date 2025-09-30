import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/auth_service.dart';
import '../services/devotional_service.dart';
import '../services/progress_tracking_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _analyticsBoxName = 'analytics_data';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DevotionalService _devotionalService = DevotionalService();
  final ProgressTrackingService _progressService = ProgressTrackingService();

  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_analyticsBoxName)) {
      await Hive.openBox(_analyticsBoxName);
    }
  }

  // Get overall app analytics
  Future<AppAnalytics> getAppAnalytics() async {
    await initialize();

    try {
      // Get user analytics
      final userAnalytics = await _getUserAnalytics();

      // Get content analytics
      final contentAnalytics = await _getContentAnalytics();

      // Get engagement analytics
      final engagementAnalytics = await _getEngagementAnalytics();

      return AppAnalytics(
        userAnalytics: userAnalytics,
        contentAnalytics: contentAnalytics,
        engagementAnalytics: engagementAnalytics,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error getting app analytics: $e');
      return AppAnalytics.empty();
    }
  }

  // Get user-specific analytics
  Future<UserAnalytics> _getUserAnalytics() async {
    final user = AuthService.currentUser;
    if (user == null) {
      return UserAnalytics.empty();
    }

    try {
      final progressSummary = await _progressService.getProgressSummary();

      return UserAnalytics(
        totalReadingSessions: progressSummary.totalDevotionalsRead,
        currentStreak: progressSummary.currentStreak,
        longestStreak: progressSummary.monthlyStats.longestStreak,
        averageReadingTime: await _getAverageReadingTime(),
        favoriteTopics: await _getFavoriteTopics(),
        readingDays: await _getReadingDays(),
        weeklyGoal: progressSummary.weeklyProgress.goal,
        goalCompletionRate: progressSummary.weeklyProgress.percentage,
      );
    } catch (e) {
      debugPrint('Error getting user analytics: $e');
      return UserAnalytics.empty();
    }
  }

  // Get content analytics
  Future<ContentAnalytics> _getContentAnalytics() async {
    try {
      final devotionals = await _devotionalService.getAllDevotionals();

      final totalDevotionals = devotionals.length;
      final authorsCount = devotionals
          .where((d) => d.author != null && d.author!.isNotEmpty)
          .map((d) => d.author!)
          .toSet()
          .length;

      // Calculate average content length
      final totalContentLength = devotionals
          .map((d) => d.content.length)
          .fold(0, (sum, length) => sum + length);
      final averageContentLength = totalDevotionals > 0
          ? (totalContentLength / totalDevotionals).round()
          : 0;

      // Get most popular topics (simplified)
      final topics = <String, int>{};
      for (final devotional in devotionals) {
        // Simple topic extraction from title and content
        final words = '${devotional.title} ${devotional.content}'
            .toLowerCase()
            .split(RegExp(r'\W+'))
            .where((word) => word.length > 4)
            .take(5);

        for (final word in words) {
          topics[word] = (topics[word] ?? 0) + 1;
        }
      }

      final popularTopics = topics.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return ContentAnalytics(
        totalDevotionals: totalDevotionals,
        totalAuthors: authorsCount,
        averageContentLength: averageContentLength,
        popularTopics: popularTopics.take(10).map((e) => e.key).toList(),
        contentDistribution: await _getContentDistribution(devotionals),
      );
    } catch (e) {
      debugPrint('Error getting content analytics: $e');
      return ContentAnalytics.empty();
    }
  }

  // Get engagement analytics
  Future<EngagementAnalytics> _getEngagementAnalytics() async {
    try {
      // This would typically come from user interaction data
      // For now, we'll use simplified calculations

      return EngagementAnalytics(
        dailyActiveUsers: await _getDailyActiveUsers(),
        weeklyActiveUsers: await _getWeeklyActiveUsers(),
        monthlyActiveUsers: await _getMonthlyActiveUsers(),
        averageSessionDuration: await _getAverageSessionDuration(),
        retentionRate: await _getRetentionRate(),
        shareCount: await _getShareCount(),
        bookmarkCount: await _getBookmarkCount(),
      );
    } catch (e) {
      debugPrint('Error getting engagement analytics: $e');
      return EngagementAnalytics.empty();
    }
  }

  // Helper methods for analytics calculations
  Future<Duration> _getAverageReadingTime() async {
    // Simplified calculation - would be tracked from actual usage
    return const Duration(minutes: 8);
  }

  Future<List<String>> _getFavoriteTopics() async {
    // Simplified - would be based on reading history
    return ['Faith', 'Hope', 'Love', 'Prayer', 'Peace'];
  }

  Future<List<DateTime>> _getReadingDays() async {
    // Get days when user read devotionals
    final readDevotionals = await _progressService.getReadDevotionals();
    // Simplified - return recent days
    final now = DateTime.now();
    return List.generate(7, (index) => now.subtract(Duration(days: index)));
  }

  Future<Map<String, int>> _getContentDistribution(
      List<dynamic> devotionals) async {
    final distribution = <String, int>{};

    for (final devotional in devotionals) {
      final month = devotional.date.month;
      final monthName = _getMonthName(month);
      distribution[monthName] = (distribution[monthName] ?? 0) + 1;
    }

    return distribution;
  }

  Future<int> _getDailyActiveUsers() async {
    // Simplified - would query actual user activity
    return 150;
  }

  Future<int> _getWeeklyActiveUsers() async {
    return 800;
  }

  Future<int> _getMonthlyActiveUsers() async {
    return 2500;
  }

  Future<Duration> _getAverageSessionDuration() async {
    return const Duration(minutes: 12);
  }

  Future<double> _getRetentionRate() async {
    return 0.75; // 75%
  }

  Future<int> _getShareCount() async {
    return 420;
  }

  Future<int> _getBookmarkCount() async {
    return 1200;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Reading pattern analysis
  Future<ReadingPatternAnalysis> getReadingPatternAnalysis() async {
    final user = AuthService.currentUser;
    if (user == null) {
      return ReadingPatternAnalysis.empty();
    }

    try {
      final progressSummary = await _progressService.getProgressSummary();

      return ReadingPatternAnalysis(
        preferredReadingTimes: await _getPreferredReadingTimes(),
        weeklyPattern: await _getWeeklyReadingPattern(),
        streakAnalysis: StreakAnalysis(
          currentStreak: progressSummary.currentStreak,
          longestStreak: progressSummary.monthlyStats.longestStreak,
          averageStreak: 5, // Simplified
          streakDistribution: [1, 3, 7, 14, 30], // Common streak lengths
        ),
        goalAchievementHistory: await _getGoalAchievementHistory(),
      );
    } catch (e) {
      debugPrint('Error getting reading pattern analysis: $e');
      return ReadingPatternAnalysis.empty();
    }
  }

  Future<Map<int, int>> _getPreferredReadingTimes() async {
    // Hour of day -> frequency
    return {
      6: 15,
      7: 25,
      8: 35,
      9: 20,
      10: 10,
      18: 30,
      19: 40,
      20: 45,
      21: 35,
      22: 20,
    };
  }

  Future<Map<String, int>> _getWeeklyReadingPattern() async {
    return {
      'Monday': 8,
      'Tuesday': 6,
      'Wednesday': 7,
      'Thursday': 5,
      'Friday': 4,
      'Saturday': 9,
      'Sunday': 10,
    };
  }

  Future<List<bool>> _getGoalAchievementHistory() async {
    // Last 12 weeks of goal achievement
    return [
      true,
      true,
      false,
      true,
      true,
      true,
      false,
      true,
      true,
      false,
      true,
      true
    ];
  }

  // Export analytics data
  Future<Map<String, dynamic>> exportAnalyticsData() async {
    final analytics = await getAppAnalytics();
    final patterns = await getReadingPatternAnalysis();

    return {
      'analytics': analytics.toJson(),
      'reading_patterns': patterns.toJson(),
      'export_date': DateTime.now().toIso8601String(),
      'user_id': AuthService.currentUser?.uid,
    };
  }
}

// Data Models
class AppAnalytics {
  final UserAnalytics userAnalytics;
  final ContentAnalytics contentAnalytics;
  final EngagementAnalytics engagementAnalytics;
  final DateTime lastUpdated;

  AppAnalytics({
    required this.userAnalytics,
    required this.contentAnalytics,
    required this.engagementAnalytics,
    required this.lastUpdated,
  });

  factory AppAnalytics.empty() {
    return AppAnalytics(
      userAnalytics: UserAnalytics.empty(),
      contentAnalytics: ContentAnalytics.empty(),
      engagementAnalytics: EngagementAnalytics.empty(),
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_analytics': userAnalytics.toJson(),
      'content_analytics': contentAnalytics.toJson(),
      'engagement_analytics': engagementAnalytics.toJson(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

class UserAnalytics {
  final int totalReadingSessions;
  final int currentStreak;
  final int longestStreak;
  final Duration averageReadingTime;
  final List<String> favoriteTopics;
  final List<DateTime> readingDays;
  final int weeklyGoal;
  final double goalCompletionRate;

  UserAnalytics({
    required this.totalReadingSessions,
    required this.currentStreak,
    required this.longestStreak,
    required this.averageReadingTime,
    required this.favoriteTopics,
    required this.readingDays,
    required this.weeklyGoal,
    required this.goalCompletionRate,
  });

  factory UserAnalytics.empty() {
    return UserAnalytics(
      totalReadingSessions: 0,
      currentStreak: 0,
      longestStreak: 0,
      averageReadingTime: Duration.zero,
      favoriteTopics: [],
      readingDays: [],
      weeklyGoal: 7,
      goalCompletionRate: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_reading_sessions': totalReadingSessions,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'average_reading_time_minutes': averageReadingTime.inMinutes,
      'favorite_topics': favoriteTopics,
      'reading_days': readingDays.map((d) => d.toIso8601String()).toList(),
      'weekly_goal': weeklyGoal,
      'goal_completion_rate': goalCompletionRate,
    };
  }
}

class ContentAnalytics {
  final int totalDevotionals;
  final int totalAuthors;
  final int averageContentLength;
  final List<String> popularTopics;
  final Map<String, int> contentDistribution;

  ContentAnalytics({
    required this.totalDevotionals,
    required this.totalAuthors,
    required this.averageContentLength,
    required this.popularTopics,
    required this.contentDistribution,
  });

  factory ContentAnalytics.empty() {
    return ContentAnalytics(
      totalDevotionals: 0,
      totalAuthors: 0,
      averageContentLength: 0,
      popularTopics: [],
      contentDistribution: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_devotionals': totalDevotionals,
      'total_authors': totalAuthors,
      'average_content_length': averageContentLength,
      'popular_topics': popularTopics,
      'content_distribution': contentDistribution,
    };
  }
}

class EngagementAnalytics {
  final int dailyActiveUsers;
  final int weeklyActiveUsers;
  final int monthlyActiveUsers;
  final Duration averageSessionDuration;
  final double retentionRate;
  final int shareCount;
  final int bookmarkCount;

  EngagementAnalytics({
    required this.dailyActiveUsers,
    required this.weeklyActiveUsers,
    required this.monthlyActiveUsers,
    required this.averageSessionDuration,
    required this.retentionRate,
    required this.shareCount,
    required this.bookmarkCount,
  });

  factory EngagementAnalytics.empty() {
    return EngagementAnalytics(
      dailyActiveUsers: 0,
      weeklyActiveUsers: 0,
      monthlyActiveUsers: 0,
      averageSessionDuration: Duration.zero,
      retentionRate: 0.0,
      shareCount: 0,
      bookmarkCount: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daily_active_users': dailyActiveUsers,
      'weekly_active_users': weeklyActiveUsers,
      'monthly_active_users': monthlyActiveUsers,
      'average_session_duration_minutes': averageSessionDuration.inMinutes,
      'retention_rate': retentionRate,
      'share_count': shareCount,
      'bookmark_count': bookmarkCount,
    };
  }
}

class ReadingPatternAnalysis {
  final Map<int, int> preferredReadingTimes;
  final Map<String, int> weeklyPattern;
  final StreakAnalysis streakAnalysis;
  final List<bool> goalAchievementHistory;

  ReadingPatternAnalysis({
    required this.preferredReadingTimes,
    required this.weeklyPattern,
    required this.streakAnalysis,
    required this.goalAchievementHistory,
  });

  factory ReadingPatternAnalysis.empty() {
    return ReadingPatternAnalysis(
      preferredReadingTimes: {},
      weeklyPattern: {},
      streakAnalysis: StreakAnalysis.empty(),
      goalAchievementHistory: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferred_reading_times': preferredReadingTimes,
      'weekly_pattern': weeklyPattern,
      'streak_analysis': streakAnalysis.toJson(),
      'goal_achievement_history': goalAchievementHistory,
    };
  }
}

class StreakAnalysis {
  final int currentStreak;
  final int longestStreak;
  final int averageStreak;
  final List<int> streakDistribution;

  StreakAnalysis({
    required this.currentStreak,
    required this.longestStreak,
    required this.averageStreak,
    required this.streakDistribution,
  });

  factory StreakAnalysis.empty() {
    return StreakAnalysis(
      currentStreak: 0,
      longestStreak: 0,
      averageStreak: 0,
      streakDistribution: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'average_streak': averageStreak,
      'streak_distribution': streakDistribution,
    };
  }
}
