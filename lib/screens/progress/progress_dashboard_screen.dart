import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/progress_tracking_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/circle_icon_badge.dart';

class ProgressDashboardScreen extends ConsumerStatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  ConsumerState<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends ConsumerState<ProgressDashboardScreen> {
  final ProgressTrackingService _progressService = ProgressTrackingService();
  ProgressSummary? _progressSummary;
  DateTime? _lastReadDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (AuthService.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _progressService.initialize();
      final summary = await _progressService.getProgressSummary();
      final lastReadDate = await _progressService.getLastReadDate();
      if (mounted) {
        setState(() {
          _progressSummary = summary;
          _lastReadDate = lastReadDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading progress: $e')),
        );
      }
    }
  }

  Future<void> _updateWeeklyGoal() async {
    final currentGoal = _progressSummary?.weeklyProgress.goal ?? 7;

    final newGoal = await showDialog<int>(
      context: context,
      builder: (context) => _WeeklyGoalDialog(currentGoal: currentGoal),
    );

    if (newGoal != null && newGoal != currentGoal) {
      await _progressService.setWeeklyGoal(newGoal);
      _loadProgress(); // Refresh the data
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _updateWeeklyGoal,
            tooltip: 'Set Weekly Goal',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AuthService.currentUser == null
              ? _buildLoginPrompt()
              : _progressSummary == null
                  ? _buildNoDataState()
                  : _buildProgressDashboard(theme),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Login Required',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Please login to track your reading progress',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'Start Your Journey',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Read your first devotional to begin tracking your progress!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDashboard(ThemeData theme) {
    final summary = _progressSummary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak hero card
          _buildStreakHeroCard(summary, theme),

          const SizedBox(height: 16),

          _buildStatCard(
            'Total Read',
            '${summary.totalDevotionalsRead}',
            'devotionals',
            Icons.menu_book,
            Colors.purple,
            theme,
          ),

          const SizedBox(height: 24),

          // Weekly progress
          _buildWeeklyProgressCard(summary.weeklyProgress, theme),

          const SizedBox(height: 24),

          // Monthly stats
          _buildMonthlyStatsCard(summary.monthlyStats, theme),

          const SizedBox(height: 24),

          // Achievements section
          _buildAchievementsCard(summary, theme),
        ],
      ),
    );
  }

  // Longer streaks get a progressively more exciting color + icon,
  // mirroring LPMI40's tiered streak treatment.
  Color _streakColor(int days) {
    if (days >= 30) return Colors.purple;
    if (days >= 14) return Colors.orange;
    if (days >= 7) return Colors.green;
    if (days >= 1) return Colors.blue;
    return Colors.grey;
  }

  IconData _streakIcon(int days) {
    if (days >= 30) return Icons.emoji_events;
    if (days >= 14) return Icons.local_fire_department;
    if (days >= 7) return Icons.whatshot;
    return Icons.calendar_today;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildStreakHeroCard(ProgressSummary summary, ThemeData theme) {
    final streak = summary.currentStreak;
    final color = _streakColor(streak);
    final icon = _streakIcon(streak);
    final bestStreak = summary.monthlyStats.longestStreak;
    final readToday =
        _lastReadDate != null && _isSameDay(_lastReadDate!, DateTime.now());

    final String microcopy;
    if (streak == 0) {
      microcopy = 'Read today to start a new streak!';
    } else if (readToday) {
      microcopy = 'Keep it going!';
    } else {
      microcopy = 'Read today to continue your streak!';
    }

    return AppCard(
      color: color.withValues(alpha: 0.1),
      child: Stack(
        children: [
          if (bestStreak > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                'Best: $bestStreak',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleIconBadge(icon: icon, color: color, size: 56, iconSize: 28),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        streak == 1 ? 'day streak' : 'days streak',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                microcopy,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleIconBadge(icon: icon, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.headlineMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressCard(WeeklyProgress weeklyProgress, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.date_range,
            iconColor: Colors.blue,
            title: 'Weekly Progress',
            trailing: TextButton(
              onPressed: _updateWeeklyGoal,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Goal: ${weeklyProgress.goal}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${weeklyProgress.daysRead}/${weeklyProgress.goal} days',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(weeklyProgress.percentage * 100).toInt()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: weeklyProgress.isGoalMet ? Colors.green : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: weeklyProgress.percentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(
                weeklyProgress.isGoalMet ? Colors.green : Colors.blue,
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (weeklyProgress.isGoalMet)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Goal achieved! 🎉',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Text(
              '${weeklyProgress.goal - weeklyProgress.daysRead} more to go',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCard(MonthlyStats monthlyStats, ThemeData theme) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.calendar_month,
            iconColor: Colors.indigo,
            title: '${monthNames[monthlyStats.month - 1]} ${monthlyStats.year}',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Devotionals',
                  '${monthlyStats.devotionalsRead}',
                  Icons.book,
                  Colors.purple,
                  theme,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  'Longest Streak',
                  '${monthlyStats.longestStreak}',
                  Icons.trending_up,
                  Colors.orange,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAchievementsCard(ProgressSummary summary, ThemeData theme) {
    final achievements = <Achievement>[
      Achievement(
        title: 'First Steps',
        description: 'Read your first devotional',
        icon: Icons.star,
        isUnlocked: summary.totalDevotionalsRead >= 1,
      ),
      Achievement(
        title: 'Consistency',
        description: 'Maintain a 7-day streak',
        icon: Icons.local_fire_department,
        isUnlocked: summary.currentStreak >= 7,
      ),
      Achievement(
        title: 'Dedicated Reader',
        description: 'Read 30 devotionals',
        icon: Icons.menu_book,
        isUnlocked: summary.totalDevotionalsRead >= 30,
      ),
      Achievement(
        title: 'Goal Crusher',
        description: 'Achieve weekly goal',
        icon: Icons.emoji_events,
        isUnlocked: summary.weeklyProgress.isGoalMet,
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.emoji_events,
            iconColor: Colors.amber,
            title: 'Achievements',
          ),
          const SizedBox(height: 16),
          ...achievements.map((achievement) => _buildAchievementItem(achievement, theme)),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleIconBadge(
            icon: achievement.icon,
            color: achievement.isUnlocked ? Colors.amber[700]! : Colors.grey,
            iconSize: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: achievement.isUnlocked ? null : Colors.grey,
                  ),
                ),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (achievement.isUnlocked)
            Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}

class _WeeklyGoalDialog extends StatefulWidget {
  final int currentGoal;

  const _WeeklyGoalDialog({required this.currentGoal});

  @override
  State<_WeeklyGoalDialog> createState() => _WeeklyGoalDialogState();
}

class _WeeklyGoalDialogState extends State<_WeeklyGoalDialog> {
  late int _selectedGoal;

  @override
  void initState() {
    super.initState();
    _selectedGoal = widget.currentGoal;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Weekly Goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How many days per week would you like to read devotionals?'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final days = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedGoal = days),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedGoal == days
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      '$days',
                      style: TextStyle(
                        color: _selectedGoal == days ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedGoal),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}