import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const BibleTab(),
    const DevotionalTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alkitab 2.0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to search screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.go('/settings');
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Bible',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Devotional',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Verse of the day card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Verse of the Day',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {},
                        iconSize: 20,
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '"For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'John 3:16',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Recent reading section
          const Text(
            'Continue Reading',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
          // Reading plans section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reading Plans',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildReadingPlanCard(
                  context,
                  'New Testament in 90 Days',
                  '90 days',
                  '12% Complete',
                  Colors.blue,
                ),
                _buildReadingPlanCard(
                  context,
                  'Wisdom Literature',
                  '30 days',
                  'Not started',
                  Colors.green,
                ),
                _buildReadingPlanCard(
                  context,
                  'Life of Jesus',
                  '21 days',
                  'Not started',
                  Colors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Devotionals section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Devotionals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDevotionalCard(
            context,
            'Finding Peace in Troubled Times',
            'Based on Philippians 4:6-7',
            'Today',
          ),
          const SizedBox(height: 12),
          _buildDevotionalCard(
            context,
            'The Power of Faith',
            'Based on Hebrews 11:1-6',
            'Yesterday',
          ),
        ],
      ),
    );
  }

  Widget _buildReadingPlanCard(
    BuildContext context,
    String title,
    String duration,
    String progress,
    Color color,
  ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    duration,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    progress,
                    style: TextStyle(
                      color: progress.contains('Not') ? Colors.grey : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
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

  Widget _buildDevotionalCard(
    BuildContext context,
    String title,
    String verse,
    String date,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              verse,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
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

class BibleTab extends StatelessWidget {
  const BibleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'OLD TESTAMENT'),
              Tab(text: 'NEW TESTAMENT'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Old Testament
                _buildTestamentList(context, [
                  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
                  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
                  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
                  'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
                  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
                  'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
                  'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
                  'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
                ]),
                // New Testament
                _buildTestamentList(context, [
                  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
                  'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
                  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
                  '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
                  '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
                  'Jude', 'Revelation',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestamentList(BuildContext context, List<String> books) {
    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(books[index]),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // Navigate to book chapters
            final bookId = books[index].toLowerCase().replaceAll(' ', '_');
            context.go('/bible-reader?bookId=$bookId&chapterId=1');
          },
        );
      },
    );
  }
}

class DevotionalTab extends StatelessWidget {
  const DevotionalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Today\'s Devotional',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finding Peace in Troubled Times',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'March 21, 2025',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.',
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Philippians 4:6-7',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'In today\'s fast-paced world, anxiety and worry have become common companions for many of us. The pressures of work, relationships, finances, and global uncertainties can easily overwhelm us if we let them. But Paul\'s words to the Philippians offer a profound alternative to living in anxiety.\n\nThis passage doesn\'t deny the reality of our troubles. Instead, it provides a divine pathway through them. When we bring our concerns to God in prayer—with an attitude of thanksgiving—we open ourselves to receive His peace. This isn\'t just any peace; it\'s a peace that "transcends all understanding."\n\nWhat makes this peace so remarkable is that it doesn\'t depend on our circumstances changing. It guards our hearts and minds even while the storms rage around us. Like a garrison of soldiers protecting a city, God\'s peace stands guard over our inner being.\n\nToday, whatever is causing you anxiety, try taking it to God in prayer. Be specific about your concerns, but also remember to express gratitude for His presence and promises. Then, watch how His incomprehensible peace begins to replace your worry.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reflection Questions:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. What specific anxieties can you bring to God today?\n\n2. How might cultivating a practice of thanksgiving help reduce your anxiety?\n\n3. Have you experienced God\'s peace in difficult circumstances before? What was that like?',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Prayer:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Heavenly Father, I bring before You my anxieties about ___________. Thank You that You care about every detail of my life. I\'m grateful for Your promise of peace that surpasses understanding. Guard my heart and mind today as I trust in You. In Jesus\' name, Amen.',
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Previous Devotionals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) {
            final titles = [
              'The Power of Faith',
              'Walking in Love',
              'Strength in Weakness',
              'The Good Shepherd',
              'Living with Purpose',
            ];
            final verses = [
              'Hebrews 11:1-6',
              '1 Corinthians 13:4-7',
              '2 Corinthians 12:9-10',
              'Psalm 23',
              'Ephesians 2:10',
            ];
            final dates = [
              'March 20',
              'March 19',
              'March 18',
              'March 17',
              'March 16',
            ];
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(titles[index]),
                subtitle: Text(verses[index]),
                trailing: Text(dates[index]),
                onTap: () {},
              ),
            );
          },
        ),
      ],
    );
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.person,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'user@example.com',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 32),
        const ListTile(
          leading: Icon(Icons.book),
          title: Text('My Reading History'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.bookmark),
          title: Text('My Bookmarks'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.highlight),
          title: Text('My Highlights'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.note),
          title: Text('My Notes'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.settings),
          title: Text('Settings'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context);
                      // ignore: use_build_context_synchronously
                      context.go('/login');
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}