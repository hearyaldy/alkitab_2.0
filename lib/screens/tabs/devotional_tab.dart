import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class DevotionalTab extends StatefulWidget {
  const DevotionalTab({Key? key}) : super(key: key);

  @override
  State<DevotionalTab> createState() => _DevotionalTabState();
}

class _DevotionalTabState extends State<DevotionalTab> {
  bool _isLoading = false;
  bool _hasError = false;

  List<dynamic> _allDevotionals = [];
  Map<String, dynamic>? _todayDevotional;

  int _readingStreak = 3;

  final TextEditingController _notesController = TextEditingController();

  final MaterialColor _themeColor = Colors.indigo;

  Set<String> _bookmarkedVerses = {};

  @override
  void initState() {
    super.initState();
    _fetchAllJsonFiles();
    _loadBookmarkedVerses();
    _loadSavedNote();
  }

  Future<void> _loadSavedNote() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('my_devotional_note');
    if (saved != null) _notesController.text = saved;
  }

  Future<void> _saveNote(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_devotional_note', value);
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

  void _pickTodayDevotional() {
    if (_allDevotionals.isEmpty) return;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final index = dayOfYear % _allDevotionals.length;
    _todayDevotional = _allDevotionals[index] as Map<String, dynamic>;
    debugPrint(
        'Today’s devotional index: $index, title: ${_todayDevotional?['title']}');
  }

  Future<void> _loadBookmarkedVerses() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('user_bookmarks')
          .select('verse_reference')
          .eq('user_id', user.id)
          .eq('bookmark_type', 'devotional');

      setState(() {
        _bookmarkedVerses = {
          for (final item in response)
            if (item['verse_reference'] != null)
              item['verse_reference'] as String
        };
      });
    } catch (e) {
      debugPrint('Failed to load bookmarks: $e');
    }
  }

  Future<void> _bookmarkDevotional(Map<String, dynamic> devotional) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to bookmark.')),
      );
      return;
    }

    final verseRef = devotional['verse_reference'];
    if (_bookmarkedVerses.contains(verseRef)) return;

    final data = {
      'user_id': user.id,
      'verse_reference': verseRef,
      'title': devotional['title'] ?? 'Untitled',
      'created_at': DateTime.now().toIso8601String(),
      'bookmark_type': 'devotional',
      'chapter_id': 0,
      'book_id': 0,
      'verse_id': 0,
    };

    try {
      final response = await Supabase.instance.client
          .from('user_bookmarks')
          .insert(data)
          .select();

      if (response.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to bookmark devotional.')),
        );
      } else {
        setState(() => _bookmarkedVerses.add(verseRef));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devotional bookmarked!')),
        );
        debugPrint('Bookmark inserted: $verseRef');
      }
    } catch (e) {
      debugPrint('Bookmark error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bookmark error: $e')),
      );
    }
  }

  void _shareDevotional(Map<String, dynamic> devotional) {
    final title = devotional['title'] ?? 'Untitled Devotional';
    final verse = devotional['verse_reference'] ?? '';
    final text = devotional['devotional_text'] ?? '';
    final prayer = devotional['prayer'] ?? '';

    final content = '''
$title
$verse

$text

🙏 $prayer
''';

    Share.share(content, subject: title);
  }

  void _showDevotionalDetails(Map<String, dynamic> devotional) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    devotional['title'] ?? 'Untitled',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    devotional['verse_reference'] ?? '',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  Text(devotional['devotional_text'] ?? '',
                      style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 16),
                  const Text('Prayer:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(devotional['prayer'] ?? '',
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
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
                Image.asset('assets/images/header_image.png',
                    fit: BoxFit.cover),
                Container(color: Colors.black.withOpacity(0.5)),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
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
                  'No devotionals found in the "devotional-readings" bucket.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              if (_todayDevotional != null)
                _buildTodayDevotion(_todayDevotional!),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Previous Devotionals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ..._allDevotionals
                  .where((dev) => dev != _todayDevotional)
                  .take(5)
                  .map((dev) {
                final title = dev['title'] ?? 'Untitled';
                final verseRef = dev['verse_reference'] ?? '';
                return ListTile(
                  title: Text(title),
                  subtitle: Text(verseRef),
                  trailing: IconButton(
                    icon: Icon(
                      _bookmarkedVerses.contains(verseRef)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    onPressed: () => _bookmarkDevotional(dev),
                  ),
                  onTap: () => _showDevotionalDetails(dev),
                );
              }).toList(),
            ]
          ]),
        ),
      ],
    );
  }

  Widget _buildTodayDevotion(Map<String, dynamic> devo) {
    final title = devo['title'] ?? 'Untitled';
    final verseRef = devo['verse_reference'] ?? '';
    final verseText = devo['verse_text'] ?? '';
    final devoText = devo['devotional_text'] ?? '';
    final reflection = devo['reflection_questions'] as List<dynamic>? ?? [];
    final prayer = devo['prayer'] ?? '';
    final now = DateTime.now();
    final dateString = '${now.month}/${now.day}/${now.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                style:
                    const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
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
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'My Notes:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                onSubmitted: _saveNote,
                decoration: InputDecoration(
                  hintText: 'Write your thoughts or prayer here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bookmark_border),
                    tooltip: 'Bookmark this Devotional',
                    onPressed: () => _bookmarkDevotional(devo),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Devotional',
                    onPressed: () => _shareDevotional(devo),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
