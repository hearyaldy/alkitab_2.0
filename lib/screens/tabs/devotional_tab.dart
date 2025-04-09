import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class DevotionalTab extends StatefulWidget {
  const DevotionalTab({Key? key}) : super(key: key);

  @override
  State<DevotionalTab> createState() => _DevotionalTabState();
}

class _DevotionalTabState extends State<DevotionalTab> {
  bool _isLoading = false;
  bool _hasError = false;

  // All devotionals from JSON
  List<dynamic> _allDevotionals = [];
  // The chosen daily item
  Map<String, dynamic>? _todayDevotional;

  // A mock reading streak
  int _readingStreak = 3;

  // Temporary notes text controller
  final TextEditingController _notesController = TextEditingController();

  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _fetchAllJsonFiles();
  }

  Future<void> _fetchAllJsonFiles() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _allDevotionals.clear();
      _todayDevotional = null;
    });

    try {
      final storage = Supabase.instance.client.storage;
      final files = await storage.from('devotional-readings').list(path: '');
      final List<dynamic> combined = [];

      for (final fileObj in files) {
        final fileName = fileObj.name;
        if (!fileName.endsWith('.json')) continue;

        final publicUrl =
            storage.from('devotional-readings').getPublicUrl(fileName);
        final response = await http.get(Uri.parse(publicUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            combined.addAll(data);
          }
        }
      }

      _allDevotionals = combined;
      _pickTodayDevotional();
    } catch (e) {
      _hasError = true;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _pickTodayDevotional() {
    if (_allDevotionals.isEmpty) return;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final index = dayOfYear % _allDevotionals.length;
    _todayDevotional = _allDevotionals[index] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // SliverAppBar
        SliverAppBar(
          pinned: true,
          expandedHeight: 160,
          flexibleSpace: FlexibleSpaceBar(
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
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/header_image.png',
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
        // Main content
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_hasError)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Oops! Failed to load devotionals.\nPlease try again later.',
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_allDevotionals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No devotionals found.'),
                )
              else
                _buildTodayDevotion(_todayDevotional ?? {}),

              const SizedBox(height: 32),
              // Possibly a "Previous Devotionals" section:
              _buildSectionHeader('Previous Devotionals'),
              const SizedBox(height: 8),
              ..._buildPreviousDevotionalList(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayDevotion(Map<String, dynamic> devo) {
    final title = devo['title'] as String? ?? 'Untitled';
    final verseRef = devo['verse_reference'] as String? ?? '';
    final verseText = devo['verse_text'] as String? ?? '';
    final devoText = devo['devotional_text'] as String? ?? '';
    final reflection = devo['reflection_questions'] as List<dynamic>? ?? [];
    final prayer = devo['prayer'] as String? ?? '';

    final now = DateTime.now();
    final dateString = '${now.month}/${now.day}/${now.year}';

    // Example container with a slight gradient for the background
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_themeColor.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Card(
          // elevation might be overshadowed by the container color,
          // but let's keep it for now
          color: Colors.transparent, // so gradient shows
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reading Streak
                Text(
                  'Streak: $_readingStreak days',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _themeColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Date
                Text(dateString, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                // Verse text
                Text(
                  verseText,
                  style: const TextStyle(
                      fontSize: 16, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                // Verse reference
                Text(
                  verseRef,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeColor.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                // Devotional text
                Text(
                  devoText,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reflection Questions:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  reflection.map((q) => '• $q').join('\n\n'),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Prayer:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  prayer,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Quick Notes
                const Text(
                  'My Notes:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write your thoughts or prayer here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (value) {
                    // Save to local or Supabase, etc. ...
                  },
                ),
                const SizedBox(height: 16),
                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      tooltip: 'Bookmark this Devotional',
                      onPressed: () {
                        // handle your bookmark logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Devotional bookmarked!')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share Devotional',
                      onPressed: () {
                        // handle share logic
                        // e.g. share the verse text, reflection
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _themeColor.shade700,
            ),
          ),
          TextButton(
            onPressed: () {
              // Link to a full list view if desired
            },
            child: const Text('See All'),
          ),
        ],
      ),
    );
  }

  /// Up to 5 random previous devotions
  List<Widget> _buildPreviousDevotionalList() {
    final others =
        _allDevotionals.where((dev) => dev != _todayDevotional).toList();

    if (others.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('No previous devotionals.'),
        ),
      ];
    }

    others.shuffle(Random());
    final randomFive = others.take(5).toList();

    return List.generate(randomFive.length, (i) {
      final devo = randomFive[i] as Map<String, dynamic>;
      final title = devo['title'] as String? ?? 'Untitled';
      final verseRef = devo['verse_reference'] as String? ?? '';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            title: Text(title),
            subtitle: Text(verseRef),
            onTap: () {
              // e.g. show detail in bottom sheet or new screen
            },
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

extension MaterialColorX on MaterialColor {
  Color get shade700 => this[700]!;
}
