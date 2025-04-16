// Updated with navigation from bookmarks into BibleReaderScreen
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String? bookId;
  final int chapterId;
  final int? scrollToVerse;

  const BibleReaderScreen(
      {super.key, this.bookId, this.chapterId = 1, this.scrollToVerse});

  @override
  BibleReaderScreenState createState() => BibleReaderScreenState();
}

class BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  late String _currentBookId;
  late int _currentChapter;
  bool _showSettings = false;
  double _fontSize = 16.0;
  String _currentVersion = 'ABB';
  late Future<List<BibleVerse>> _versesFuture;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Set<String> _bookmarks = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.bookId ?? 'genesis';
    _currentChapter = widget.chapterId;
    _versesFuture = _fetchVerses();
    _loadBookmarks();

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollToVerse != null && _scrollController.hasClients) {
        final index = widget.scrollToVerse! - 1;
        _scrollController.animateTo(
          index * 80.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<List<BibleVerse>> _fetchVerses() async {
    const versionUrls = {
      'ABB':
          'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tm.json',
      'ATB':
          'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tb.json',
    };
    final url = versionUrls[_currentVersion];
    if (url == null) throw Exception('Unknown Bible version $_currentVersion');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Failed to load verses');
    final jsonData = json.decode(response.body);
    final List<dynamic> allVerses = jsonData['verses'];
    final bookNum = getBookIndex(_currentBookId);
    final filtered = allVerses
        .where((v) => v['book'] == bookNum && v['chapter'] == _currentChapter)
        .toList();
    return filtered
        .map((v) => BibleVerse(
              id: v['verse'],
              bookId: _currentBookId,
              chapterId: v['chapter'],
              verseNumber: v['verse'],
              text: v['text'],
            ))
        .toList();
  }

  void _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bookmarks') ?? [];
    setState(() => _bookmarks = saved.toSet());
  }

  Future<void> _toggleBookmark(String key) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarks.contains(key)) {
        _bookmarks.remove(key);
      } else {
        _bookmarks.add(key);
      }
      prefs.setStringList('bookmarks', _bookmarks.toList());
    });
  }

  Future<void> _speakChapter(List<BibleVerse> verses) async {
    final text = verses.map((v) => '${v.verseNumber}. ${v.text}').join(' ');
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  Widget _buildVerseItem(BibleVerse verse) {
    final key = '${verse.bookId}_${verse.chapterId}_${verse.verseNumber}';
    final bookmarked = _bookmarks.contains(key);
    return GestureDetector(
      onLongPress: () => _toggleBookmark(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${verse.verseNumber} ',
                style: TextStyle(
                  fontSize: _fontSize - 2,
                  fontWeight: FontWeight.bold,
                  color: bookmarked ? Colors.blue : Colors.grey[700],
                ),
              ),
              TextSpan(
                text: verse.text,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: Colors.black,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bible'),
        ),
        title: Text('${getBookName(_currentBookId)} Fasal $_currentChapter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            tooltip: 'Lihat Bookmark',
            onPressed: () {
              final bookmarks = _bookmarks.toList();
              if (bookmarks.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tiada bookmark disimpan.')),
                );
              } else {
                context.go('/bookmarks');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () async {
              final verses = await _versesFuture;
              _isSpeaking ? await _stopSpeaking() : await _speakChapter(verses);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<BibleVerse>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final verses = snapshot.data!;
            return ListView.builder(
              controller: _scrollController,
              itemCount: verses.length,
              itemBuilder: (context, index) => _buildVerseItem(verses[index]),
            );
          }
        },
      ),
    );
  }
}
