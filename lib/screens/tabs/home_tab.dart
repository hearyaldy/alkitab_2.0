import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Format current date and day in Malay.
    final now = DateTime.now();
    final formattedDate =
        DateFormat.yMMMMd('ms').format(now); // e.g., "1 Januari 2025"
    final dayName = DateFormat('EEEE', 'ms').format(now); // e.g., "Isnin"

    // Retrieve current user's display name.
    final user = Supabase.instance.client.auth.currentUser;
    final displayName =
        user?.userMetadata?['full_name'] ?? user?.email ?? "Guest";
    final firstName = displayName.split(" ").first;

    return CustomScrollView(
      slivers: [
        // Collapsible header with background image.
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left: App name and date/day.
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alkitab 2.0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 08,
                              color: Colors.white70,
                            ),
                          ),
                          const Text(
                            ' | ',
                            style: TextStyle(
                              fontSize: 08,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            dayName,
                            style: const TextStyle(
                              fontSize: 08,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Right: User profile photo and greeting with right padding.
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.person,
                            size: 16, color: Colors.indigo),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Welcome, $firstName!",
                        style:
                            const TextStyle(fontSize: 08, color: Colors.white),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/header_image.png', // Ensure asset exists in your pubspec.yaml.
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
        // Main content.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verse of the Day card.
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.indigo.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.wb_sunny, color: Colors.indigo),
                            const SizedBox(width: 8),
                            const Text(
                              'Verse of the Day',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () {},
                              tooltip: 'Share verse',
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          '"For God so loved the world that He gave His one and only Son..."',
                          style: TextStyle(
                              fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'John 3:16',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Continue Reading section.
                const Text(
                  'Continue Reading',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: const Text('Matthew 5'),
                    subtitle: const Text('The Sermon on the Mount'),
                    trailing: const Text('60%'),
                    onTap: () {
                      context.go('/bible-reader?bookId=matt&chapterId=5');
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Reading Plans section.
                _sectionHeader(context, 'Reading Plans', onSeeAll: () {}),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildReadingPlanCard(context, 'New Testament in 90 Days',
                          '90 days', '12% Complete', Colors.blue),
                      _buildReadingPlanCard(context, 'Wisdom Literature',
                          '30 days', 'Not started', Colors.green),
                      _buildReadingPlanCard(context, 'Life of Jesus', '21 days',
                          'Not started', Colors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Daily Devotionals section.
                _sectionHeader(context, 'Daily Devotionals', onSeeAll: () {}),
                const SizedBox(height: 12),
                _buildDevotionalCard(context, 'Finding Peace in Troubled Times',
                    'Based on Philippians 4:6–7', 'Today', Colors.indigo),
                const SizedBox(height: 12),
                _buildDevotionalCard(context, 'The Power of Faith',
                    'Based on Hebrews 11:1–6', 'Yesterday', Colors.indigo),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    );
  }

  Widget _buildReadingPlanCard(BuildContext context, String title,
      String duration, String progress, Color color) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4), // Reduced vertical padding.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4), // Reduced from 8 to 4.
                  Text(
                    duration,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4), // Reduced spacing.
                  Text(
                    progress,
                    style: TextStyle(
                      color:
                          progress.contains('Not') ? Colors.grey : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced spacing.
                  progress.contains('Not')
                      ? ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 30),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Start'),
                        )
                      : const LinearProgressIndicator(value: 0.12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevotionalCard(BuildContext context, String title, String verse,
      String date, Color themeColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensure Column fits its content.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(date,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(verse, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () {}, child: const Text('Read')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
