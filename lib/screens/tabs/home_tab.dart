import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<void> _initializationFuture;
  List<Map<String, dynamic>> _devotionals = [];
  Map<String, dynamic>? _todayDevo;
  List<Map<String, dynamic>> _recentReadings = [];

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadDevotionals();
    await _loadReadingHistory();
  }

  Future<void> _loadDevotionals() async {
    try {
      final storage = Supabase.instance.client.storage;
      final files = await storage.from('devotional-readings').list(path: '');
      final List<Map<String, dynamic>> combined = [];

      for (final file in files) {
        if (!file.name.endsWith('.json')) continue;
        final res =
            await storage.from('devotional-readings').download(file.name);
        final jsonData = jsonDecode(utf8.decode(res));
        if (jsonData is List) {
          combined.addAll(jsonData.cast<Map<String, dynamic>>());
        }
      }

      _devotionals = combined;
      _todayDevo = _pickTodayDevo(combined);
    } catch (e) {
      debugPrint('Error loading devotionals: $e');
    }
  }

  Map<String, dynamic>? _pickTodayDevo(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return null;
    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(now.year)).inDays % list.length;
    return list[dayIndex];
  }

  Future<void> _loadReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('last_readings') ?? [];
    _recentReadings = data
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList()
        .reversed
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildMainContent(context);
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat.yMMMMd('ms').format(now);
    final dayName = DateFormat('EEEE', 'ms').format(now);
    final user = Supabase.instance.client.auth.currentUser;
    final displayName =
        user?.userMetadata?['full_name'] ?? user?.email ?? "Guest";
    final firstName = displayName.split(" ").first;
    final profileUrl = user?.userMetadata?['profile_url'];

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alkitab 2.0',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(formattedDate,
                              style: const TextStyle(
                                  fontSize: 8, color: Colors.white70)),
                          const Text(' | ',
                              style: TextStyle(
                                  fontSize: 8, color: Colors.white70)),
                          Text(dayName,
                              style: const TextStyle(
                                  fontSize: 8, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: profileUrl != null
                            ? NetworkImage(profileUrl)
                            : null,
                        backgroundColor: Colors.white,
                        child: profileUrl == null
                            ? const Icon(Icons.person,
                                size: 16, color: Colors.indigo)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text("Welcome, $firstName!",
                          style: const TextStyle(
                              fontSize: 8, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/header_image.png',
                    fit: BoxFit.cover),
                Container(color: Colors.black.withOpacity(0.4)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _verseOfDayCard(),
                const SizedBox(height: 24),
                _continueReadingSection(),
                const SizedBox(height: 24),
                _devotionalSection(),
                const SizedBox(height: 24),
                _sectionHeader(context, 'Reading Plans', onSeeAll: () {}),
                const SizedBox(height: 12),
                _readingPlansList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDevotionalDetails(Map<String, dynamic> devo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(devo['title'] ?? 'Untitled',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(devo['verse_reference'] ?? '',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Text(devo['devotional_text'] ?? '',
                  style: const TextStyle(height: 1.5)),
              const SizedBox(height: 16),
              const Text('Prayer:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(devo['prayer'] ?? '',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verseOfDayCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Verse of the Day',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share verse',
                  onPressed: () {
                    final verse = _todayDevo!['verse_text'] ?? '';
                    final reference = _todayDevo!['verse_reference'] ?? '';
                    final content = '"$verse"\n\n📖 $reference';
                    Share.share(content, subject: 'Verse of the Day');
                  },
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('"${_todayDevo!['verse_text']}"',
                style:
                    const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(
              _todayDevo!['verse_reference'] ?? '',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _continueReadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Continue Reading',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._recentReadings.map((entry) {
          final book = entry['bookId'] ?? 'Unknown';
          final chapter = entry['chapterId'] ?? 1;
          final bookName = entry['bookName'] ?? book;
          final progress = (entry['progress'] ?? 0.0) as double;
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text('$bookName Chapter $chapter'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${(progress * 100).round()}% read'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: progress),
                ],
              ),
              onTap: () =>
                  context.go('/bible-reader?bookId=$book&chapterId=$chapter'),
            ),
          );
        }),
      ],
    );
  }

  Widget _devotionalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Devotionals',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._devotionals.where((d) => d != _todayDevo).take(2).map((dev) => Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                title: Text(dev['title'] ?? 'Untitled'),
                subtitle: Text(dev['verse_reference'] ?? ''),
                trailing: const Text('Earlier'),
                onTap: () => _showDevotionalDetails(dev),
              ),
            )),
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

  Widget _readingPlansList() {
    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildReadingPlanCard('New Testament in 90 Days', '90 days',
              '12% Complete', Colors.blue),
          _buildReadingPlanCard(
              'Wisdom Literature', '30 days', 'Not started', Colors.green),
          _buildReadingPlanCard(
              'Life of Jesus', '21 days', 'Not started', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildReadingPlanCard(
      String title, String duration, String progress, Color color) {
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
                    topRight: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2),
                  const SizedBox(height: 4),
                  Text(duration,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(progress,
                      style: TextStyle(
                          color: progress.contains('Not')
                              ? Colors.grey
                              : Colors.green,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  progress.contains('Not')
                      ? ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 30),
                              padding: EdgeInsets.zero),
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
}
