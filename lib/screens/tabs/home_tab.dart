import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _devotionals = [];
  Map<String, dynamic>? _todayDevo;

  @override
  void initState() {
    super.initState();
    _loadDevotionals();
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

      setState(() {
        _devotionals = combined;
        _todayDevo = _pickTodayDevo(combined);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading devotionals: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _pickTodayDevo(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return null;
    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(now.year)).inDays % list.length;
    return list[dayIndex];
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
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(devo['verse_reference'] ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Text(devo['devotional_text'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Text('Prayer:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(devo['prayer'] ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
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

  Widget _buildShimmerCard({double height = 140}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(width: double.infinity, height: height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat.yMMMMd('ms').format(now);
    final dayName = DateFormat('EEEE', 'ms').format(now);
    final user = Supabase.instance.client.auth.currentUser;
    final displayName =
        user?.userMetadata?['full_name'] ?? user?.email ?? "Guest";
    final firstName = displayName.split(" ").first;

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
                      Text('Alkitab 2.0',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(formattedDate,
                              style: const TextStyle(
                                  fontSize: 08, color: Colors.white70)),
                          const Text(' | ',
                              style: TextStyle(
                                  fontSize: 08, color: Colors.white70)),
                          Text(dayName,
                              style: const TextStyle(
                                  fontSize: 08, color: Colors.white70)),
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
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.person,
                              size: 16, color: Colors.indigo)),
                      const SizedBox(height: 4),
                      Text("Welcome, $firstName!",
                          style: const TextStyle(
                              fontSize: 08, color: Colors.white)),
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
            child: _isLoading
                ? Column(
                    children: [
                      _buildShimmerCard(height: 160),
                      const SizedBox(height: 24),
                      _buildShimmerCard(height: 80),
                      const SizedBox(height: 16),
                      _buildShimmerCard(height: 80),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _todayDevo != null
                          ? _buildVerseOfTheDayCard(context)
                          : const SizedBox.shrink(),
                      const SizedBox(height: 24),
                      _buildDevotionalList(context),
                      const SizedBox(height: 24),
                      _buildReadingPlanList(context),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerseOfTheDayCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
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
                Text('Verse of the Day',
                    style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
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
            Text(
              '"${_todayDevo!['verse_text']}"',
              style: textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              _todayDevo!['verse_reference'] ?? '',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevotionalList(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Devotionals',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildReadingPlanList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Reading Plans'),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildReadingPlanCard(context, 'New Testament in 90 Days',
                  '90 days', '12% Complete', Colors.blue),
              _buildReadingPlanCard(context, 'Wisdom Literature', '30 days',
                  'Not started', Colors.green),
              _buildReadingPlanCard(context, 'Life of Jesus', '21 days',
                  'Not started', Colors.purple),
            ],
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
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        TextButton(onPressed: onSeeAll ?? () {}, child: const Text('See All')),
      ],
    );
  }

  Widget _buildReadingPlanCard(BuildContext context, String title,
      String duration, String progress, Color color) {
    final theme = Theme.of(context);
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(duration,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    progress,
                    style: TextStyle(
                      color:
                          progress.contains('Not') ? Colors.grey : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
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
}
