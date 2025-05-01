import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/bible_service.dart';
import 'package:alkitab_2_0/providers/highlight_provider.dart';
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
    state = {...state, verseKey: colorHex};
    _saveHighlights();
  }

  void addMultipleHighlights(Map<String, String> highlights) {
    state = {...state, ...highlights};
    _saveHighlights();
  }

  void removeHighlight(String verseKey) {
    final newState = Map<String, String>.from(state);
    newState.remove(verseKey);
    state = newState;
    _saveHighlights();
  }

  void removeMultipleHighlights(List<String> verseKeys) {
    final newState = Map<String, String>.from(state);
    for (final key in verseKeys) {
      newState.remove(key);
    }
    state = newState;
    _saveHighlights();
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
  final Set<int> _selectedVerses = {};
  bool _isSelectionMode = false;
  bool _highlightsLoaded = false;

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
    return await BibleService.fetchVerses(
      bookId: _currentBookId,
      chapterId: _currentChapter,
      version: _currentVersion,
    );
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

  void _toggleVerseSelection(int verse) {
    setState(() {
      if (_selectedVerses.contains(verse)) {
        _selectedVerses.remove(verse);
      } else {
        _selectedVerses.add(verse);
      }
      _isSelectionMode = _selectedVerses.isNotEmpty;
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

  String _getVerseKey(int verseNumber) {
    return '${_currentBookId}_${_currentChapter}_$verseNumber';
  }

  // Load any existing highlights from the original provider if they exist
  void _loadExistingHighlights(List<BibleVerse> verses) async {
    if (_highlightsLoaded) return;
    
    // Get all existing provider highlights for this chapter
    final Map<String, String> highlightsToAdd = {};
    
    for (final verse in verses) {
      try {
        final colorAsync = ref.read(
          highlightColorProvider((_currentBookId, _currentChapter, verse.verseNumber))
        );
        
        final colorHex = await colorAsync.when(
          data: (color) => color,
          loading: () => null,
          error: (_, __) => null,
        );
        
        if (colorHex != null) {
          final verseKey = _getVerseKey(verse.verseNumber);
          highlightsToAdd[verseKey] = colorHex;
        }
      } catch (e) {
        debugPrint('Error loading highlight for verse ${verse.verseNumber}: $e');
      }
    }
    
    // Add any found highlights to our store
    if (highlightsToAdd.isNotEmpty) {
      ref.read(highlightStoreProvider.notifier).addMultipleHighlights(highlightsToAdd);
    }
    
    _highlightsLoaded = true;
  }

  Widget _buildVerse(BibleVerse verse) {
    // Get highlight from our store
    final highlightsMap = ref.watch(highlightStoreProvider);
    final verseKey = _getVerseKey(verse.verseNumber);
    final colorHex = highlightsMap[verseKey];
    
    // Get the color 
    final highlightColor = _parseColor(colorHex);

    return GestureDetector(
      onLongPress: () => _toggleVerseSelection(verse.verseNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: _selectedVerses.contains(verse.verseNumber)
            ? Colors.blue.withOpacity(0.1)
            : highlightColor,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookName = getBookName(_currentBookId);
    return Scaffold(
      appBar: AppBar(
        title: Text('$bookName $_currentChapter'),
        actions: [
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
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Failed to load verses.'));
          }

          final verses = snapshot.data!;
          
          // Load existing highlights if not already loaded
          if (!_highlightsLoaded) {
            _loadExistingHighlights(verses);
          }
          
          return ListView.builder(
            controller: _scrollController,
            itemCount: verses.length,
            itemBuilder: (_, i) => _buildVerse(verses[i]),
          );
        },
      ),
      persistentFooterButtons: _isSelectionMode
          ? [
              TextButton(
                onPressed: () => setState(() {
                  _selectedVerses.clear();
                  _isSelectionMode = false;
                }),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _showHighlightOptions,
                child: const Text('Highlight'),
              ),
            ]
          : null,
    );
  }

  void _showHighlightOptions() {
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
                    _handleHighlight(colorHex);
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
                _handleRemoveHighlight();
              },
              child: const Text('Remove Highlight'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleHighlight(String colorHex) {
    // Make a copy of selected verses before clearing
    final versesToHighlight = List<int>.from(_selectedVerses);
    final highlightStore = ref.read(highlightStoreProvider.notifier);
    
    // Add new highlights to the store
    for (final verseNum in versesToHighlight) {
      final verseKey = _getVerseKey(verseNum);
      highlightStore.addHighlight(verseKey, colorHex);
    }
    
    // Clear selection
    setState(() {
      _selectedVerses.clear();
      _isSelectionMode = false;
    });
  }

  void _handleRemoveHighlight() {
    // Make a copy of selected verses before clearing
    final versesToRemove = List<int>.from(_selectedVerses);
    final verseKeysToRemove = versesToRemove.map((num) => _getVerseKey(num)).toList();
    
    // Remove highlights from store
    ref.read(highlightStoreProvider.notifier).removeMultipleHighlights(verseKeysToRemove);
    
    // Clear selection
    setState(() {
      _selectedVerses.clear();
      _isSelectionMode = false;
    });
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
          return GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _currentChapter = chapter;
                _versesFuture = _loadVerses();
                _highlightsLoaded = false; // Reset so we load highlights for the new chapter
              });
            },
            child: Card(
              child: Center(child: Text('$chapter')),
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