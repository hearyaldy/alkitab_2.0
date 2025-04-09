import 'package:flutter/material.dart';

class DevotionalTab extends StatelessWidget {
  const DevotionalTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.indigo;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/header_image.png',
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
            title: const Text(
              'Daily Devotional',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 16),
              _buildTodayDevotion(themeColor),
              const SizedBox(height: 32),
              _buildSectionHeader('Previous Devotionals', themeColor),
              const SizedBox(height: 8),
              ..._buildDevotionalList(themeColor),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayDevotion(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finding Peace in Troubled Times',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'April 3, 2025',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving...',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              Text(
                'Filipi 4:6–7',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeColor.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'In today\'s fast-paced world, anxiety and worry have become common. Paul\'s letter to the Philippians reminds us to replace worry with prayer and thanksgiving...',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reflection Questions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. What specific anxieties can you bring to God today?\n\n'
                '2. How might thanksgiving help reduce your anxiety?\n\n'
                '3. Have you experienced God\'s peace in hardship before?',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Prayer:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lord, I bring my anxieties to You. Thank You for Your peace that goes beyond understanding. Guard my heart and mind today. Amen.',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              )),
          TextButton(onPressed: () {}, child: const Text('See All')),
        ],
      ),
    );
  }

  List<Widget> _buildDevotionalList(Color color) {
    final titles = [
      'The Power of Faith',
      'Walking in Love',
      'Strength in Weakness',
      'The Good Shepherd',
      'Living with Purpose',
    ];
    final verses = [
      'Ibrani 11:1–6',
      '1 Korintus 13:4–7',
      '2 Korintus 12:9–10',
      'Mazmur 23',
      'Efesus 2:10',
    ];
    final dates = [
      'April 2',
      'April 1',
      'March 31',
      'March 30',
      'March 29',
    ];

    return List.generate(titles.length, (i) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            title: Text(titles[i]),
            subtitle: Text(verses[i]),
            trailing: Text(dates[i]),
            onTap: () {},
          ),
        ),
      );
    });
  }
}

extension on Color {
  get shade700 => null;
}
