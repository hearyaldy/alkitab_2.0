import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/collapsible_header.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.indigo;

    return CollapsibleHeader(
      title: 'Alkitab 2.0',
      imagePath: 'assets/images/header_image.png',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: themeColor.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wb_sunny, color: themeColor),
                        const SizedBox(width: 8),
                        Text(
                          'Verse of the Day',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
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
                      style:
                          TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'John 3:16',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeColor.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Continue Reading',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeColor.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.bookmark, color: themeColor),
                title: const Text('Matthew 5'),
                subtitle: const Text('The Sermon on the Mount'),
                trailing: const Text('60%'),
                onTap: () {
                  context.go('/bible-reader?bookId=matt&chapterId=5');
                },
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader(context, 'Reading Plans', onSeeAll: () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildPlanCard('New Testament in 90 Days', '90 days',
                      '12% Complete', themeColor),
                  _buildPlanCard('Wisdom Literature', '30 days', 'Not started',
                      Colors.green),
                  _buildPlanCard(
                      'Life of Jesus', '21 days', 'Not started', Colors.purple),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader(context, 'Daily Devotionals', onSeeAll: () {}),
            const SizedBox(height: 12),
            _buildDevotionalCard('Finding Peace in Troubled Times',
                'Based on Philippians 4:6–7', 'Today', themeColor),
            const SizedBox(height: 12),
            _buildDevotionalCard('The Power of Faith',
                'Based on Hebrews 11:1–6', 'Yesterday', themeColor),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            )),
        TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    );
  }

  Widget _buildPlanCard(
      String title, String duration, String progress, Color color) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(duration,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 16),
                  Text(
                    progress,
                    style: TextStyle(
                      color:
                          progress.contains('Not') ? Colors.grey : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  progress.contains('Not')
                      ? OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(30)),
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

  Widget _buildDevotionalCard(
      String title, String verse, String date, Color themeColor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                    color: themeColor.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(date,
                      style: TextStyle(fontSize: 12, color: themeColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(verse, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Read'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on Color {
  get shade50 => null;
}
