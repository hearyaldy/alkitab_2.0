import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/progress_tracking_service.dart';
import '../../services/auth_service.dart';

class ProgressDashboardScreen extends ConsumerStatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  ConsumerState<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends ConsumerState<ProgressDashboardScreen> {
  final ProgressTrackingService _progressService = ProgressTrackingService();
  ProgressSummary? _progressSummary;
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
      if (mounted) {
        setState(() {
          _progressSummary = summary;
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
          // Header stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Current Streak',
                  '${summary.currentStreak}',
                  'days',
                  Icons.local_fire_department,
                  Colors.orange,
                  theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Read',
                  '${summary.totalDevotionalsRead}',
                  'devotionals',
                  Icons.menu_book,
                  Colors.blue,
                  theme,
                ),
              ),
            ],
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

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Weekly Progress',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _updateWeeklyGoal,
                child: Text(
                  'Goal: ${weeklyProgress.goal}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
                  color: weeklyProgress.isGoalMet ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: weeklyProgress.percentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(
              weeklyProgress.isGoalMet ? Colors.green : Colors.orange,
            ),
            minHeight: 8,
          ),
          if (weeklyProgress.isGoalMet) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Goal achieved! 🎉',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCard(MonthlyStats monthlyStats, ThemeData theme) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                '${monthNames[monthlyStats.month - 1]} ${monthlyStats.year}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'Devotionals',
                  '${monthlyStats.devotionalsRead}',
                  Icons.book,
                  theme,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  'Longest Streak',
                  '${monthlyStats.longestStreak}',
                  Icons.trending_up,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: theme.primaryColor, size: 32),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Achievements',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: achievement.isUnlocked
                  ? Colors.yellow.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              achievement.icon,
              color: achievement.isUnlocked ? Colors.yellow[700] : Colors.grey,
              size: 24,
            ),
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