// lib/screens/bible/bible_reader_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String _footerText = '';
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Set<String> _bookmarks = {};
  final ScrollController _scrollController = ScrollController();

  // Verse selection state
  final Set<int> _selectedVerses = {};
  bool _isSelectionMode = false;

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

    _saveReadingProgress();
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

  Future<void> _saveReadingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    final key = '$_currentBookId-$_currentChapter';

    final progressList = prefs.getStringList('last_readings') ?? [];
    final updated = [
      jsonEncode({
        'bookId': _currentBookId,
        'chapterId': _currentChapter,
        'bookName': getBookName(_currentBookId),
        'timestamp': now,
      }),
      ...progressList.where((entry) {
        final data = jsonDecode(entry);
        return data['bookId'] != _currentBookId ||
            data['chapterId'] != _currentChapter;
      }),
    ];

    await prefs.setStringList(
        'last_readings', updated.take(5).toList()); // keep latest 5

    // Store book-level progress
    final maxChapters = getMaxChapters(_currentBookId);
    final progress = (_currentChapter / maxChapters).clamp(0.0, 1.0);
    await prefs.setDouble('progress_$_currentBookId', progress);
  }

  void _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bookmarks') ?? [];
    setState(() => _bookmarks = saved.toSet());

    // Also sync with Supabase bookmarks if user is logged in
    _syncBookmarksWithSupabase();
  }

  // Sync local bookmarks with Supabase
  Future<void> _syncBookmarksWithSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('user_bookmarks')
          .select()
          .eq('user_id', user.id)
          .eq('type', 'bible');

      final Set<String> supabaseBookmarks = {};

      for (final bookmark in response) {
        final bookId = bookmark['book_id'];
        final chapterId = bookmark['chapter_id'];
        final verseId = bookmark['verse_id'];

        if (bookId != null && chapterId != null && verseId != null) {
          supabaseBookmarks.add('${bookId}_${chapterId}_$verseId');
        }
      }

      // Update local bookmarks to include Supabase bookmarks
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _bookmarks = supabaseBookmarks;
      });
      prefs.setStringList('bookmarks', _bookmarks.toList());
    } catch (e) {
      debugPrint('Error syncing bookmarks: $e');
    }
  }

  // Toggle bookmark using both local storage and Supabase
  Future<void> _toggleSupabaseBookmark(String key, BibleVerse verse) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to bookmark verses')),
      );
      return;
    }

    try {
      // Check if bookmark exists
      final bookName = getBookName(_currentBookId);
      final verseReference = '$bookName $_currentChapter:${verse.verseNumber}';

      final existing = await Supabase.instance.client
          .from('user_bookmarks')
          .select()
          .eq('user_id', user.id)
          .eq('verse_reference', verseReference)
          .eq('type', 'bible')
          .maybeSingle();

      if (existing != null) {
        // Delete existing bookmark
        await Supabase.instance.client
            .from('user_bookmarks')
            .delete()
            .eq('id', existing['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark removed')),
        );
      } else {
        // Create new bookmark
        await Supabase.instance.client.from('user_bookmarks').insert({
          'user_id': user.id,
          'title': 'Bible - $verseReference',
          'verse_reference': verseReference,
          'verse_text': verse.text,
          'type': 'bible',
          'bookmark_type': 'bible_verse',
          'book_id': _currentBookId,
          'chapter_id': _currentChapter,
          'verse_id': verse.verseNumber,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark added')),
        );
      }

      // Also update local bookmarks for immediate feedback
      setState(() {
        if (_bookmarks.contains(key)) {
          _bookmarks.remove(key);
        } else {
          _bookmarks.add(key);
        }
      });

      // Update shared preferences for offline access
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList('bookmarks', _bookmarks.toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error managing bookmark: $e')),
      );
    }
  }

  // Navigate to the bookmarks screen
  void _navigateToBookmarksScreen() {
    context.go('/bookmarks');
  }

  // Toggle verse selection
  void _toggleVerseSelection(int verseNumber) {
    setState(() {
      if (_selectedVerses.contains(verseNumber)) {
        _selectedVerses.remove(verseNumber);
      } else {
        _selectedVerses.add(verseNumber);
      }
      _isSelectionMode = _selectedVerses.isNotEmpty;
    });
  }

  // Copy a single verse
  void _copySingleVerse(BibleVerse verse) {
    final bookName = getBookName(_currentBookId);
    final verseText = '${verse.verseNumber}. ${verse.text}';

    Clipboard.setData(ClipboardData(
      text: '$bookName $_currentChapter\n\n$verseText',
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayat disalin')),
    );
  }

  // Share a single verse
  void _shareSingleVerse(BibleVerse verse) {
    final bookName = getBookName(_currentBookId);
    final verseText = '${verse.verseNumber}. ${verse.text}';

    Share.share(
      '$bookName $_currentChapter\n\n$verseText\n\n#AlkitabApp',
    );
  }

  // Copy selected verses
  void _copySelectedVerses(List<BibleVerse> verses) {
    final selectedVerseTexts = verses
        .where((verse) => _selectedVerses.contains(verse.verseNumber))
        .map((verse) => '${verse.verseNumber}. ${verse.text}')
        .join('\n\n');

    final bookName = getBookName(_currentBookId);

    Clipboard.setData(ClipboardData(
      text: '$bookName $_currentChapter\n\n$selectedVerseTexts',
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayat disalin')),
    );

    // Clear selection after copying
    setState(() {
      _selectedVerses.clear();
      _isSelectionMode = false;
    });
  }

  // Share selected verses
  void _shareSelectedVerses(List<BibleVerse> verses) {
    final selectedVerseTexts = verses
        .where((verse) => _selectedVerses.contains(verse.verseNumber))
        .map((verse) => '${verse.verseNumber}. ${verse.text}')
        .join('\n\n');

    final bookName = getBookName(_currentBookId);

    Share.share(
      '$bookName $_currentChapter\n\n$selectedVerseTexts\n\n#AlkitabApp',
    );

    // Clear selection after sharing
    setState(() {
      _selectedVerses.clear();
      _isSelectionMode = false;
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
    final isSelected = _selectedVerses.contains(verse.verseNumber);

    return GestureDetector(
      onLongPress: () {
        if (_isSelectionMode) {
          _toggleVerseSelection(verse.verseNumber);
        } else {
          // Show popup menu for the verse
          final RenderBox button = context.findRenderObject() as RenderBox;
          final RenderBox overlay = Navigator.of(context)
              .overlay!
              .context
              .findRenderObject() as RenderBox;
          final RelativeRect position = RelativeRect.fromRect(
            Rect.fromPoints(
              button.localToGlobal(Offset.zero, ancestor: overlay),
              button.localToGlobal(button.size.bottomRight(Offset.zero),
                  ancestor: overlay),
            ),
            Offset.zero & overlay.size,
          );

          showMenu(
            context: context,
            position: position,
            items: [
              PopupMenuItem(
                value: 'select',
                child: Row(
                  children: const [
                    Icon(Icons.select_all, size: 20),
                    SizedBox(width: 8),
                    Text('Pilih Ayat'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: const [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 8),
                    Text('Salin Ayat'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: const [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('Bagikan Ayat'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'bookmark',
                child: Row(
                  children: [
                    Icon(
                      bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(bookmarked ? 'Hapus Bookmark' : 'Tambah Bookmark'),
                  ],
                ),
              ),
            ],
          ).then((value) async {
            if (value == 'select') {
              setState(() {
                _isSelectionMode = true;
                _selectedVerses.add(verse.verseNumber);
              });
            } else if (value == 'copy') {
              _copySingleVerse(verse);
            } else if (value == 'share') {
              _shareSingleVerse(verse);
            } else if (value == 'bookmark') {
              // Use Supabase bookmark method
              _toggleSupabaseBookmark(key, verse);
            }
          });
        }
      },
      onTap: _isSelectionMode
          ? () => _toggleVerseSelection(verse.verseNumber)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        color: isSelected ? Colors.blue.withAlpha(40) : Colors.transparent,
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
                _saveReadingProgress();

                // Clear any selections when changing chapters
                _selectedVerses.clear();
                _isSelectionMode = false;
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

  // Show version selection dialog
  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Versi Alkitab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Alkitab Berita Baik (ABB)'),
              value: 'ABB',
              groupValue: _currentVersion,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _currentVersion = value!;
                  _versesFuture = _fetchVerses();
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Alkitab Terjemahan Baru (ATB)'),
              value: 'ATB',
              groupValue: _currentVersion,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _currentVersion = value!;
                  _versesFuture = _fetchVerses();
                });
              },
            ),
          ],
        ),
      ),
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
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    final verses = await _versesFuture;
                    _copySelectedVerses(verses);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    final verses = await _versesFuture;
                    _shareSelectedVerses(verses);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedVerses.clear();
                    _isSelectionMode = false;
                  }),
                ),
              ]
            : [
                // Bookmark icon to navigate to bookmarks screen
                IconButton(
                  icon: const Icon(Icons.bookmarks),
                  onPressed: _navigateToBookmarksScreen,
                ),
                IconButton(
                  icon: const Icon(Icons.translate),
                  onPressed: _showVersionDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(
                      () => _fontSize = (_fontSize - 2).clamp(12.0, 28.0)),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(
                      () => _fontSize = (_fontSize + 2).clamp(12.0, 28.0)),
                ),
                IconButton(
                  icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                  onPressed: () async {
                    final verses = await _versesFuture;
                    _isSpeaking
                        ? await _stopSpeaking()
                        : await _speakChapter(verses);
                  },
                ),
              ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
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
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  children: [
                    Text(bookName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 4),
                    Text('Pasal $_currentChapter',
                        style: const TextStyle(
                            fontSize: 14, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              if (_isSelectionMode)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.blue.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedVerses.length} ayat dipilih',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedVerses.clear();
                          _isSelectionMode = false;
                        }),
                        child: const Text('Batal'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: verses.length,
                  itemBuilder: (context, index) =>
                      _buildVerseItem(verses[index]),
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

  @override
  void dispose() {
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }
}
