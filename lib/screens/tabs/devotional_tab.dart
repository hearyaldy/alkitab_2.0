import 'dart:convert';
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

  // All devotionals from all JSON files combined
  List<dynamic> _allDevotionals = [];
  // The one we pick for “Today’s Devotional”
  Map<String, dynamic>? _todayDevotional;

  // Base MaterialColor for styling
  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _fetchAllJsonFiles();
  }

  /// 1) Lists all files in the “devotional-readings” bucket
  /// 2) For each file with a .json extension, get a public URL and fetch/parse it
  /// 3) Combine all devotionals into _allDevotionals
  /// 4) Pick one for today
  Future<void> _fetchAllJsonFiles() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _allDevotionals.clear();
      _todayDevotional = null;
    });

    try {
      final storage = Supabase.instance.client.storage;
      // List all objects in “devotional-readings” bucket
      final files = await storage.from('devotional-readings').list(path: '');
      // Temporary storage
      final List<dynamic> combined = [];

      for (final fileObj in files) {
        final fileName = fileObj.name; // e.g. "Set1.json"
        if (!fileName.endsWith('.json')) continue; // Only process JSON files

        // Build a public URL
        final publicUrl =
            storage.from('devotional-readings').getPublicUrl(fileName);

        // Fetch the file content
        final response = await http.get(Uri.parse(publicUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Append if it's a JSON list
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

  /// Picks one item from the combined devotionals for “today,”
  /// based on day-of-year mod list length. This yields a stable daily pick.
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
        // Collapsible SliverAppBar
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
                  'assets/images/header_image.png', // your background image
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black.withOpacity(0.54),
                ),
              ],
            ),
          ),
        ),
        // Main Sliver content
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
                if (_todayDevotional != null)
                  _buildTodayDevotion(_todayDevotional!)
                else
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No devotionals available.'),
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

  /// Builds the top card for today's devotional
  Widget _buildTodayDevotion(Map<String, dynamic> devo) {
    final title = devo['title'] as String? ?? 'Untitled';
    final verseRef = devo['verse_reference'] as String? ?? '';
    final verseText = devo['verse_text'] as String? ?? '';
    final devoText = devo['devotional_text'] as String? ?? '';
    final reflection = devo['reflection_questions'] as List<dynamic>? ?? [];
    final prayer = devo['prayer'] as String? ?? '';

    // Example date display: M/D/YYYY
    final now = DateTime.now();
    final dateString = '${now.month}/${now.day}/${now.year}';

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
              Text(
                dateString,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              // Verse text
              Text(
                verseText,
                style:
                    const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              // Verse reference in bold
              Text(
                verseRef,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _themeColor.shade700,
                ),
              ),
              const SizedBox(height: 16),
              // Devotional content
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
            ],
          ),
        ),
      ),
    );
  }

  /// Section Header for “Previous Devotionals”
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
              // If you want to navigate to a full list page
            },
            child: const Text('See All'),
          ),
        ],
      ),
    );
  }

  /// Builds a list of the other devotionals that are NOT today's
  List<Widget> _buildPreviousDevotionalList() {
    final others =
        _allDevotionals.where((dev) => dev != _todayDevotional).toList();

    return List.generate(others.length, (i) {
      final devo = others[i] as Map<String, dynamic>;
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
              // If you want a detail view for older devotionals
            },
          ),
        ),
      );
    });
  }
}

/// Optional extension for MaterialColor so you can do: _themeColor.shade700
extension MaterialColorX on MaterialColor {
  Color get shade700 => this[700]!;
}
