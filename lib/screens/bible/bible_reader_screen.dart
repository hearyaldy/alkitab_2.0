import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/bible_service.dart';
import 'dart:convert';

// Provider for managing highlights with offline storage
final highlightStoreProvider = StateNotifierProvider<HighlightStore, Map<String, String>>((ref) {
  return HighlightStore();
});

// StateNotifier to manage highlights with persistence
class HighlightStore extends StateNotifier<Map<String, String>> {
  HighlightStore() : super({}) {
    _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final highlightsJson = prefs.getString('bible_highlights');
      
      if (highlightsJson != null) {
        final Map<String, dynamic> decodedMap = json.decode(highlightsJson);
        
        // Convert to the expected format
        final Map<String, String> highlightMap = {};
        decodedMap.forEach((key, value) {
          if (value is String) {
            highlightMap[key] = value;
          }
        });
        
        state = highlightMap;
      }
    } catch (e) {
      debugPrint('Error loading highlights: $e');
    }
  }

  Future<void> _saveHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_highlights', json.encode(state));
    } catch (e) {
      debugPrint('Error saving highlights: $e');
    }
  }

  void addHighlight(String verseKey, String colorHex) {
    final newState = Map<String, String>.from(state);
    newState[verseKey] = colorHex;
    state = newState;
    _saveHighlights();
  }

  void removeHighlight(String verseKey) {
    final newState = Map<String, String>.from(state);
    newState.remove(verseKey);
    state = newState;
    _saveHighlights();
  }
}

// Provider for managing verse bookmarks
final verseBookmarkProvider = StateNotifierProvider<VerseBookmarkStore, Set<String>>((ref) {
  return VerseBookmarkStore();
});

// StateNotifier to manage verse bookmarks with persistence
class VerseBookmarkStore extends StateNotifier<Set<String>> {
  VerseBookmarkStore() : super({}) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getString('bible_verse_bookmarks');
      
      if (bookmarksJson != null) {
        final List<dynamic> decoded = json.decode(bookmarksJson);
        state = decoded.map((item) => item.toString()).toSet();
      }
    } catch (e) {
      debugPrint('Error loading verse bookmarks: $e');
    }
  }

  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_verse_bookmarks', json.encode(state.toList()));
    } catch (e) {
      debugPrint('Error saving verse bookmarks: $e');
    }
  }

  void toggleVerseBookmark(String verseKey) {
    final newState = Set<String>.from(state);
    
    if (newState.contains(verseKey)) {
      newState.remove(verseKey);
    } else {
      newState.add(verseKey);
    }
    
    state = newState;
    _saveBookmarks();
  }

  bool isVerseBookmarked(String verseKey) {
    return state.contains(verseKey);
  }
}

// Provider for managing chapter bookmarks
final chapterBookmarkProvider = StateNotifierProvider<ChapterBookmarkStore, Set<String>>((ref) {
  return ChapterBookmarkStore();
});

// StateNotifier to manage chapter bookmarks with persistence
class ChapterBookmarkStore extends StateNotifier<Set<String>> {
  ChapterBookmarkStore() : super({}) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getString('bible_chapter_bookmarks');
      
      if (bookmarksJson != null) {
        final List<dynamic> decoded = json.decode(bookmarksJson);
        state = decoded.map((item) => item.toString()).toSet();
      }
    } catch (e) {
      debugPrint('Error loading chapter bookmarks: $e');
    }
  }

  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_chapter_bookmarks', json.encode(state.toList()));
    } catch (e) {
      debugPrint('Error saving chapter bookmarks: $e');
    }
  }

  void toggleChapterBookmark(String chapterKey) {
    final newState = Set<String>.from(state);
    
    if (newState.contains(chapterKey)) {
      newState.remove(chapterKey);
    } else {
      newState.add(chapterKey);
    }
    
    state = newState;
    _saveBookmarks();
  }

  bool isChapterBookmarked(String chapterKey) {
    return state.contains(chapterKey);
  }
}

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
  ConsumerState<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  late String _currentBookId;
  late int _currentChapter;
  double _fontSize = 16.0;
  String _currentVersion = 'ABB';
  late Future<List<BibleVerse>> _versesFuture;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  final ScrollController _scrollController = ScrollController();
  bool _verseOptionsVisible = false;
  late BibleVerse _selectedVerse;

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.bookId ?? 'genesis';
    _currentChapter = widget.chapterId;
    _versesFuture = _loadVerses();

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });

    _saveReadingProgress();
    
    // If scrollToVerse is provided, scroll to that verse after rendering
    if (widget.scrollToVerse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(widget.scrollToVerse!);
      });
    }
  }

  String _getChapterKey() {
    return '${_currentBookId}_${_currentChapter}';
  }

  String _getVerseKey(int verseNumber) {
    return '${_currentBookId}_${_currentChapter}_$verseNumber';
  }

  void _scrollToVerse(int verseNumber) {
    if (_scrollController.hasClients) {
      // Approximate scroll position - you might need to adjust this
      // based on your actual verse heights
      _scrollController.animateTo(
        (verseNumber - 1) * 80.0, // Estimated height per verse
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<List<BibleVerse>> _loadVerses() async {
    try {
      // Try to load from local storage first using Bible Service
      return await BibleService.fetchVerses(
        bookId: _currentBookId,
        chapterId: _currentChapter,
        version: _currentVersion,
      );
    } catch (e) {
      debugPrint('Error loading verses: $e');
      return [];
    }
  }

  Future<void> _saveReadingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();

    final progressList = prefs.getStringList('last_readings') ?? [];
    final updated = [
      '{"bookId":"$_currentBookId","chapterId":$_currentChapter,"bookName":"${getBookName(_currentBookId)}","timestamp":"$now"}',
      ...progressList.where((e) => !e.contains(_currentBookId)),
    ];

    await prefs.setStringList('last_readings', updated.take(5).toList());
    final max = getMaxChapters(_currentBookId);
    await prefs.setDouble('progress_$_currentBookId', (_currentChapter / max));
  }

  void _toggleChapterBookmark() {
    final chapterKey = _getChapterKey();
    ref.read(chapterBookmarkProvider.notifier).toggleChapterBookmark(chapterKey);
  }

  void _toggleVerseBookmark(BibleVerse verse) {
    final verseKey = _getVerseKey(verse.verseNumber);
    ref.read(verseBookmarkProvider.notifier).toggleVerseBookmark(verseKey);
    _closeVerseOptions();
  }

  void _showVerseOptions(BibleVerse verse) {
    setState(() {
      _verseOptionsVisible = true;
      _selectedVerse = verse;
    });
    
    _showVerseOptionsBottomSheet(verse);
  }

  void _closeVerseOptions() {
    setState(() {
      _verseOptionsVisible = false;
    });
  }

  Future<void> _speakChapter(List<BibleVerse> verses) async {
    final text = verses.map((v) => '${v.verseNumber}. ${v.text}').join(' ');
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  Future<void> _speakVerse(BibleVerse verse) async {
    final text = '${verse.verseNumber}. ${verse.text}';
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
    _closeVerseOptions();
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  Color? _parseColor(String? colorHex) {
    if (colorHex == null) return null;
    try {
      if (colorHex.startsWith('#')) {
        return Color(int.parse('0xFF${colorHex.substring(1)}'));
      } else {
        return Color(int.parse(colorHex));
      }
    } catch (e) {
      debugPrint('Error parsing color: $e');
      return null;
    }
  }

  Widget _buildVerse(BibleVerse verse) {
    // Get highlight from our store
    final highlightsMap = ref.watch(highlightStoreProvider);
    final verseKey = _getVerseKey(verse.verseNumber);
    final colorHex = highlightsMap[verseKey];
    
    // Check if verse is bookmarked
    final isVerseBookmarked = ref.watch(verseBookmarkProvider).contains(verseKey);
    
    // Get the color 
    final highlightColor = _parseColor(colorHex);

    return GestureDetector(
      onLongPress: () => _showVerseOptions(verse),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: highlightColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${verse.verseNumber}. ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _fontSize,
                        color: Colors.grey[700],
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
            if (isVerseBookmarked)
              Icon(
                Icons.bookmark,
                color: Colors.amber,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookName = getBookName(_currentBookId);
    final isChapterBookmarked = ref.watch(chapterBookmarkProvider).contains(_getChapterKey());
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate directly to the home screen using GoRouter
            context.go('/home');
          },
        ),
        title: Text('$bookName $_currentChapter'),
        actions: [
          IconButton(
            icon: Icon(
              isChapterBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isChapterBookmarked ? Colors.amber : null,
            ),
            onPressed: _toggleChapterBookmark,
          ),
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopSpeaking,
            )
          else
            IconButton(
              icon: const Icon(Icons.volume_up),
              onPressed: () async {
                final verses = await _versesFuture;
                _speakChapter(verses);
              },
            ),
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: () => setState(() {
              _currentVersion = _currentVersion == 'ABB' ? 'ATB' : 'ABB';
              _versesFuture = _loadVerses();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: _showChapterPicker,
          ),
        ],
      ),
      body: FutureBuilder<List<BibleVerse>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Failed to load verses.'));
          }

          final verses = snapshot.data!;
          
          return ListView.builder(
            controller: _scrollController,
            itemCount: verses.length,
            itemBuilder: (_, i) => _buildVerse(verses[i]),
          );
        },
      ),
    );
  }

  void _showVerseOptionsBottomSheet(BibleVerse verse) {
    final verseKey = _getVerseKey(verse.verseNumber);
    final isVerseBookmarked = ref.read(verseBookmarkProvider).contains(verseKey);
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Verse ${verse.verseNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              verse.text,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionButton(
                  icon: isVerseBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  label: isVerseBookmarked ? 'Remove Bookmark' : 'Bookmark',
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleVerseBookmark(verse);
                  },
                ),
                _buildOptionButton(
                  icon: Icons.record_voice_over,
                  label: 'Read Aloud',
                  onTap: () {
                    Navigator.pop(ctx);
                    _speakVerse(verse);
                  },
                ),
                _buildOptionButton(
                  icon: Icons.brush,
                  label: 'Highlight',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showHighlightOptions(verse);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showHighlightOptions(BibleVerse verse) {
    final colors = [
      '#FFEB3B', // Yellow
      '#90CAF9', // Light Blue
      '#A5D6A7', // Light Green
      '#FFAB91', // Light Orange
      '#E1BEE7', // Light Purple
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose highlight color', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: colors.map((colorHex) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleHighlight(verse, colorHex);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(colorHex),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleRemoveHighlight(verse);
              },
              child: const Text('Remove Highlight'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleHighlight(BibleVerse verse, String colorHex) {
    final verseKey = _getVerseKey(verse.verseNumber);
    ref.read(highlightStoreProvider.notifier).addHighlight(verseKey, colorHex);
  }

  void _handleRemoveHighlight(BibleVerse verse) {
    final verseKey = _getVerseKey(verse.verseNumber);
    ref.read(highlightStoreProvider.notifier).removeHighlight(verseKey);
  }

  void _showChapterPicker() {
    final maxChapters = getMaxChapters(_currentBookId);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => GridView.count(
        crossAxisCount: 5,
        padding: const EdgeInsets.all(16),
        children: List.generate(maxChapters, (i) {
          final chapter = i + 1;
          final chapterKey = '${_currentBookId}_$chapter';
          final isBookmarked = ref.read(chapterBookmarkProvider).contains(chapterKey);
          
          return GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _currentChapter = chapter;
                _versesFuture = _loadVerses();
              });
            },
            child: Card(
              child: Stack(
                children: [
                  Center(child: Text('$chapter')),
                  if (isBookmarked)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(Icons.bookmark, color: Colors.amber, size: 14),
                    ),
                ],
              ),
            ),
          );
        }),
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