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

  const BibleReaderScreen({
    super.key,
    this.bookId,
    this.chapterId = 1,
    this.scrollToVerse,
  });

  @override
  BibleReaderScreenState createState() => BibleReaderScreenState();
}

class BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  late String _currentBookId;
  late int _currentChapter;
  double _fontSize = 16.0;
  String _currentVersion = 'ABB';
  late Future<List<BibleVerse>> _versesFuture;
  List<BibleVerse> _searchResults = [];
  String _footerText = '';
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
    _footerText = jsonData['metadata']?['footer'] ?? '';

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
    try {
      final text = verses.map((v) => '${v.verseNumber}. ${v.text}').join(' ');
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
      setState(() => _isSpeaking = true);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('TTS Error: $e')));
    }
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
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
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
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterPicker() {
    final max = getMaxChapters(_currentBookId);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: max,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
        itemBuilder: (context, index) {
          final chapter = index + 1;
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _currentChapter = chapter;
                _versesFuture = _fetchVerses();
                _searchResults = [];
              });
            },
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              color: chapter == _currentChapter
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                  : Theme.of(context).cardColor,
              child: Center(
                child: Text(
                  chapter.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: chapter == _currentChapter
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cari Ayat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Masukkan kata kunci'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                final keyword = controller.text.toLowerCase();
                final verses = await _versesFuture;
                setState(() {
                  _searchResults = verses
                      .where((v) => v.text.toLowerCase().contains(keyword))
                      .toList();
                });
                Navigator.pop(context);
              },
              child: const Text('Cari'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookName = getBookName(_currentBookId);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bookName, style: const TextStyle(fontSize: 16)),
            Text(
              'Pasal $_currentChapter',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bible'),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.search), onPressed: _showSearchDialog),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize - 2).clamp(12.0, 28.0)),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize + 2).clamp(12.0, 28.0)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showChapterPicker,
        tooltip: 'Pilih Pasal',
        child: const Icon(Icons.grid_view),
      ),
      body: FutureBuilder<List<BibleVerse>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final verses = snapshot.data!;
          final contentList =
              _searchResults.isNotEmpty ? _searchResults : verses;

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceVariant,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  children: [
                    Text(bookName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Pasal $_currentChapter',
                        style: const TextStyle(
                            fontSize: 14, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: contentList.length,
                  itemBuilder: (context, index) =>
                      _buildVerseItem(contentList[index]),
                ),
              ),
              if (_footerText.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    _footerText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
