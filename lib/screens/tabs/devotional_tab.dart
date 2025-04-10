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

  // Combined list of devotionals from all JSON files.
  List<dynamic> _allDevotionals = [];
  // Today's devotional chosen based on day-of-year mod.
  Map<String, dynamic>? _todayDevotional;

  // Example reading streak value
  int _readingStreak = 3;

  // A controller for the "My Notes" field
  final TextEditingController _notesController = TextEditingController();

  // Base color for styling
  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _fetchAllJsonFiles();
  }

  /// Fetch all JSON files from the public bucket "devotional-readings",
  /// parse their content, combine the devotionals, then pick a daily item.
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
        final fileName = fileObj.name; // e.g. "Set1.json", "Set2.json", etc.
        if (!fileName.endsWith('.json')) continue;
        final publicUrl =
            storage.from('devotional-readings').getPublicUrl(fileName);
        final response = await http.get(Uri.parse(publicUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            combined.addAll(data);
          }
        } else {
          debugPrint('Error fetching $fileName: ${response.statusCode}');
        }
      }
      _allDevotionals = combined;
      _pickTodayDevotional();
    } catch (e) {
      debugPrint('Error listing/fetching devotionals: $e');
      _hasError = true;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Chooses a "today" devotional based on day-of-year mod list length.
  void _pickTodayDevotional() {
    if (_allDevotionals.isEmpty) return;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final index = dayOfYear % _allDevotionals.length;
    _todayDevotional = _allDevotionals[index] as Map<String, dynamic>;
    debugPrint(
        'Today’s devotional index: $index, title: ${_todayDevotional?["title"]}');
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Collapsible header with SliverAppBar
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
                  'assets/images/header_image.png', // Customize your header image
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
        // Main content in a SliverList
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
                  child: Text(
                    'No devotionals found in the “devotional-readings” bucket.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                // Today's Devotional card
                if (_todayDevotional != null)
                  _buildTodayDevotion(_todayDevotional!)
                else
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No devotional available for today.'),
                  ),
                const SizedBox(height: 32),
                _buildSectionHeader('Previous Devotionals'),
                const SizedBox(height: 8),
                ..._buildPreviousDevotionalList(),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the "Today’s Devotional" card with additional features.
  Widget _buildTodayDevotion(Map<String, dynamic> devo) {
    final title = devo['title'] as String? ?? 'Untitled';
    final verseRef = devo['verse_reference'] as String? ?? '';
    final verseText = devo['verse_text'] as String? ?? '';
    final devoText = devo['devotional_text'] as String? ?? '';
    final reflection = devo['reflection_questions'] as List<dynamic>? ?? [];
    final prayer = devo['prayer'] as String? ?? '';

    // Display current date
    final now = DateTime.now();
    final dateString = '${now.month}/${now.day}/${now.year}';

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
          color: Colors.transparent,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reading streak and date row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Streak: $_readingStreak days',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange[800],
                      ),
                    ),
                    Text(
                      dateString,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Devotional title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _themeColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Verse text and reference
                Text(
                  verseText,
                  style: const TextStyle(
                      fontSize: 16, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 4),
                Text(
                  verseRef,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeColor.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                // Main devotional text
                Text(
                  devoText,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reflection Questions:',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  reflection.map((q) => '• $q').join('\n\n'),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Prayer:',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  prayer,
                  style: const TextStyle(
                      fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
                ),
                const SizedBox(height: 20),
                // Notes field for user's reflections
                const Text(
                  'My Notes:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
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
                    // Implement note saving logic here (local or Supabase)
                  },
                ),
                const SizedBox(height: 16),
                // Action buttons for sharing and bookmarking
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      tooltip: 'Bookmark this Devotional',
                      onPressed: () {
                        // Implement bookmarking logic here.
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
                        // For actual sharing, integrate the share_plus package.
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

  /// Builds the section header for previous devotionals.
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
              // Optionally navigate to a full list of devotionals.
            },
            child: const Text('See All'),
          ),
        ],
      ),
    );
  }

  /// Builds a list of up to 5 random previous devotionals.
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
            onTap: () => _showDevotionalDetail(devo),
          ),
        ),
      );
    });
  }

  /// Displays a detailed view of the devotional in a bottom sheet including a Close button.
  void _showDevotionalDetail(Map<String, dynamic> devo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final title = devo['title'] as String? ?? 'Untitled';
        final verseRef = devo['verse_reference'] as String? ?? '';
        final verseText = devo['verse_text'] as String? ?? '';
        final devoText = devo['devotional_text'] as String? ?? '';
        final reflection = devo['reflection_questions'] as List<dynamic>? ?? [];
        final prayer = devo['prayer'] as String? ?? '';

        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _themeColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verseText,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verseRef,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _themeColor.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        fontSize: 16, fontStyle: FontStyle.italic, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  // Close button to dismiss the bottom sheet
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

/// Extension to simplify access to a specific shade of MaterialColor.
extension MaterialColorX on MaterialColor {
  Color get shade700 => this[700]!;
}
