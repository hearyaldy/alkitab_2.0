// lib/screens/bible/bible_reader_screen.dart

import 'dart:convert';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/bible_service.dart';
import 'package:alkitab_2_0/services/highlight_service.dart';

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
  // Define connectivity subscription properly
  StreamSubscription? _connectivitySubscription;

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
  bool _isOffline = false;
  bool _loadedFromCache = false;
  int _loadTimeMillis = 0;

  // Highlighting
  Map<int, BibleHighlight> _highlights = {};
  String _selectedColor = HighlightColors.yellow;

  // Verse selection state
  final Set<int> _selectedVerses = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.bookId ?? 'genesis';
    _currentChapter = widget.chapterId;
    _initializeConnectivity();
    _loadBibleVersion();
    _versesFuture = _fetchVerses();
    _loadBookmarks();
    _loadHighlights(); // Load highlights for the current chapter

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });

    _saveReadingProgress();

    // Set up connectivity change listener more safely
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      final offline = result == ConnectivityResult.none;
      if (offline != _isOffline) {
        setState(() {
          _isOffline = offline;
        });

        // Try to sync when back online
        if (!offline && _isOffline) {
          _syncBookmarksWithSupabase();
          _syncReadingProgressWithSupabase();
          _syncHighlightsWithSupabase();
        }
      }
    });
  }

  // Load highlights for the current chapter
  Future<void> _loadHighlights() async {
    final highlights = await HighlightService.getChapterHighlights(
      _currentBookId,
      _currentChapter,
    );

    setState(() {
      _highlights = {for (var h in highlights) h.verseNumber: h};
    });
  }

  // Sync highlights with Supabase when back online
  Future<void> _syncHighlightsWithSupabase() async {
    await HighlightService.syncAllHighlights();
    await _loadHighlights(); // Reload highlights after sync
  }

  Future<void> _initializeConnectivity() async {
    // Using direct Connectivity check instead
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  Future<void> _loadBibleVersion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentVersion = prefs.getString('preferred_bible_version') ?? 'ABB';
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

  // Use BibleService to fetch verses with offline capability
  Future<List<BibleVerse>> _fetchVerses() async {
    final stopwatch = Stopwatch()..start();

    try {
      // Check if content is cached before making request
      final boxName =
          'bible_verses_${_currentVersion}_${_currentBookId}_$_currentChapter';
      final box = await Hive.openBox(boxName);
      setState(() {
        _loadedFromCache = box.isNotEmpty;
      });

      // Use the BibleService's fetchVerses method which handles offline caching
      final verses = await BibleService.fetchVerses(
        bookId: _currentBookId,
        chapterId: _currentChapter,
        version: _currentVersion,
      );

      // Record load time
      stopwatch.stop();
      setState(() {
        _loadTimeMillis = stopwatch.elapsedMilliseconds;
      });

      // Check for footer text (only available online)
      if (!_isOffline) {
        await _fetchFooterText();
      }

      return verses;
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _loadTimeMillis = stopwatch.elapsedMilliseconds;
      });
      debugPrint('Error fetching verses: $e');
      return [];
    }
  }

  // Fetch footer text separately (non-critical data)
  Future<void> _fetchFooterText() async {
    if (_isOffline) return;

    const versionUrls = {
      'ABB':
          'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tm.json',
      'ATB':
          'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tb.json',
    };

    try {
      final url = versionUrls[_currentVersion];
      if (url == null) return;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          _footerText = jsonData['metadata']?['footer'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching footer text: $e');
    }
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

    // Save if user is logged in and online
    if (!_isOffline) {
      _syncReadingProgressWithSupabase();
    }
  }

  // Sync reading progress with Supabase
  Future<void> _syncReadingProgressWithSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('profiles').update({
        'last_read_book': _currentBookId,
        'last_read_chapter': _currentChapter,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Error syncing reading progress: $e');
    }
  }

  void _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bookmarks') ?? [];
    setState(() => _bookmarks = saved.toSet());

    // Also sync with Supabase bookmarks if user is logged in and online
    if (!_isOffline) {
      _syncBookmarksWithSupabase();
    }
  }

  // Sync local bookmarks with Supabase
  Future<void> _syncBookmarksWithSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isOffline) return;

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
  Future<void> _toggleBookmark(String key, BibleVerse verse) async {
    // First update local state for immediate feedback
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

    // If online and logged in, sync with Supabase
    if (!_isOffline) {
      await _toggleSupabaseBookmark(key, verse);
    } else {
      // If offline, add to pending sync queue
      await _addToPendingSyncQueue('bookmark', {
        'key': key,
        'bookId': verse.bookId,
        'chapterId': verse.chapterId,
        'verseNumber': verse.verseNumber,
        'text': verse.text,
        'action': _bookmarks.contains(key) ? 'add' : 'remove',
      });
    }
  }

  // Toggle highlight for a verse
  Future<void> _toggleHighlight(int verseNumber, BibleVerse verse) async {
    if (_highlights.containsKey(verseNumber)) {
      // Remove existing highlight
      await HighlightService.removeHighlight(
        _currentBookId,
        _currentChapter,
        verseNumber,
      );

      setState(() {
        _highlights.remove(verseNumber);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Highlight removed')),
      );
    } else {
      // Add new highlight
      final highlight = await HighlightService.addHighlight(
        bookId: _currentBookId,
        chapterId: _currentChapter,
        verseNumber: verseNumber,
        colorHex: _selectedColor,
      );

      setState(() {
        _highlights[verseNumber] = highlight;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Highlight added')),
      );
    }
  }

  // Show color picker dialog
  void _showColorPickerDialog(int verseNumber, BibleVerse verse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Highlight Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: HighlightColors.all().map((colorHex) {
            final color = Color(int.parse(colorHex, radix: 16));
            final isSelected = _selectedColor == colorHex;

            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedColor = colorHex;
                });

                // Apply the highlight
                _toggleHighlight(verseNumber, verse);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 2,
                  ),
                ),
                height: 40,
                width: double.infinity,
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.black54)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Add item to pending sync queue for when device is back online
  Future<void> _addToPendingSyncQueue(
      String type, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingActions = prefs.getStringList('pending_sync_actions') ?? [];

    pendingActions.add(jsonEncode({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    }));

    await prefs.setStringList('pending_sync_actions', pendingActions);
  }

  // Toggle bookmark in Supabase
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

  // Navigate to the highlights screen
  void _navigateToHighlightsScreen() {
    context.go('/highlights');
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
    final highlight = _highlights[verse.verseNumber];

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
              // Add highlight menu item
              PopupMenuItem(
                value: 'highlight',
                child: Row(
                  children: [
                    Icon(
                      highlight != null ? Icons.brush : Icons.brush_outlined,
                      size: 20,
                      color: highlight != null
                          ? Color(int.parse(highlight.colorHex, radix: 16))
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(highlight != null
                        ? 'Ubah Highlight'
                        : 'Highlight Ayat'),
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
              _toggleBookmark(key, verse);
            } else if (value == 'highlight') {
              _showColorPickerDialog(verse.verseNumber, verse);
            }
          });
        }
      },
      onTap: _isSelectionMode
          ? () => _toggleVerseSelection(verse.verseNumber)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        color: highlight != null
            ? Color(int.parse(highlight.colorHex, radix: 16))
            : (isSelected ? Colors.blue.withAlpha(40) : Colors.transparent),
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

              // Load highlights for the new chapter
              _loadHighlights();
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

                // Save preference
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString('preferred_bible_version', value!);
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

                // Save preference
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString('preferred_bible_version', value!);
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
                color: Colors.black54,
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
                // Highlight icon to navigate to highlights screen
                IconButton(
                  icon: const Icon(Icons.brush),
                  onPressed: _navigateToHighlightsScreen,
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
      body: Column(
        children: [
          // Offline indicator directly in the widget
          if (_isOffline)
            Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Mode Offline - Perubahan akan disinkronkan nanti',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: FutureBuilder<List<BibleVerse>>(
              future: _versesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _versesFuture = _fetchVerses();
                            });
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final verses = snapshot.data ?? [];
                if (verses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.book_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Tidak ada ayat yang ditemukan'),
                        if (_isOffline)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Anda sedang dalam mode offline. Konten ini mungkin belum diunduh.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _versesFuture = _fetchVerses();
                            });
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
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
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic)),

                              // Add cache indicator
                              if (snapshot.connectionState !=
                                  ConnectionState.waiting)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _loadedFromCache
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _loadedFromCache
                                            ? Icons.storage
                                            : Icons.cloud_download,
                                        size: 10,
                                        color: _loadedFromCache
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _loadedFromCache
                                            ? 'From cache (${_loadTimeMillis}ms)'
                                            : 'From network (${_loadTimeMillis}ms)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _loadedFromCache
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tts.stop();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
