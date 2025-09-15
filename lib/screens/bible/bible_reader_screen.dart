import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/bible_service.dart';
import 'dart:convert';

final highlightStoreProvider =
    StateNotifierProvider<HighlightStore, Map<String, String>>(
        (ref) => HighlightStore());

class HighlightStore extends StateNotifier<Map<String, String>> {
  HighlightStore() : super({}) {
    _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final highlightsJson = prefs.getString('bible_highlights');
      if (highlightsJson != null) {
        final decodedMap =
            Map<String, dynamic>.from(json.decode(highlightsJson));
        state = decodedMap.map((key, value) => MapEntry(key, value.toString()));
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

  void removeHighlight(String verseKey) {
    final newState = Map<String, String>.from(state);
    newState.remove(verseKey);
    state = newState;
    _saveHighlights();
  }
}

final chapterBookmarkProvider =
    StateNotifierProvider<ChapterBookmarkStore, Set<String>>(
        (ref) => ChapterBookmarkStore());

class ChapterBookmarkStore extends StateNotifier<Set<String>> {
  ChapterBookmarkStore() : super({}) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bible_chapter_bookmarks') ?? [];
    state = saved.toSet();
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bible_chapter_bookmarks', state.toList());
  }

  void toggleChapterBookmark(String chapterKey) async {
    final newState = Set<String>.from(state);
    final user = Supabase.instance.client.auth.currentUser;
    final parts = chapterKey.split('_');

    if (newState.contains(chapterKey)) {
      newState.remove(chapterKey);
      if (user != null) {
        await Supabase.instance.client
            .from('user_bookmarks')
            .delete()
            .eq('user_id', user.id)
            .eq('book_id', parts[0])
            .eq('chapter_id', int.parse(parts[1]))
            .isFilter('verse_id', null)
            .eq('type', 'bible');
      }
    } else {
      newState.add(chapterKey);
      if (user != null) {
        await Supabase.instance.client.from('user_bookmarks').insert({
          'user_id': user.id,
          'type': 'bible',
          'bookmark_type': 'bible_chapter',
          'book_id': parts[0],
          'chapter_id': int.parse(parts[1]),
          'verse_id': null,
          'verse_reference': '${parts[0]} ${parts[1]}',
          'title': 'Bible - ${parts[0]} ${parts[1]}',
        });
      }
    }

    state = newState;
    _saveBookmarks();
  }

  bool isChapterBookmarked(String chapterKey) {
    return state.contains(chapterKey);
  }
}

final verseBookmarkProvider =
    StateNotifierProvider<VerseBookmarkStore, Set<String>>(
        (ref) => VerseBookmarkStore());

class VerseBookmarkStore extends StateNotifier<Set<String>> {
  VerseBookmarkStore() : super({}) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bible_verse_bookmarks') ?? [];
    state = saved.toSet();
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bible_verse_bookmarks', state.toList());
  }

  void toggleVerseBookmark(String verseKey) async {
    final newState = Set<String>.from(state);
    final user = Supabase.instance.client.auth.currentUser;
    final parts = verseKey.split('_');

    if (newState.contains(verseKey)) {
      newState.remove(verseKey);
      if (user != null) {
        await Supabase.instance.client
            .from('user_bookmarks')
            .delete()
            .eq('user_id', user.id)
            .eq('book_id', parts[0])
            .eq('chapter_id', int.parse(parts[1]))
            .eq('verse_id', int.parse(parts[2]))
            .eq('type', 'bible');
      }
    } else {
      newState.add(verseKey);
      if (user != null) {
        await Supabase.instance.client.from('user_bookmarks').insert({
          'user_id': user.id,
          'type': 'bible',
          'bookmark_type': 'bible_verse',
          'book_id': parts[0],
          'chapter_id': int.parse(parts[1]),
          'verse_id': int.parse(parts[2]),
          'verse_reference': '${parts[0]} ${parts[1]}:${parts[2]}',
          'title': 'Bible - ${parts[0]} ${parts[1]}:${parts[2]}',
        });
      }
    }

    state = newState;
    _saveBookmarks();
  }

  bool isVerseBookmarked(String verseKey) {
    return state.contains(verseKey);
  }
}

// Current Bible translation provider
final currentTranslationProvider = StateProvider<String>((ref) => 'indo_tb');

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String? bookId;
  final int chapterId;
  final int? scrollToVerse;

  const BibleReaderScreen({
    super.key,
    required this.bookId,
    required this.chapterId,
    this.scrollToVerse,
  });

  @override
  ConsumerState<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  late FlutterTts flutterTts;
  bool isPlaying = false;
  int currentVerseIndex = 0;
  String currentBookId = '';
  int currentChapterId = 1;
  late final BibleService bibleService;
  List<BibleVerse> verses = [];
  bool isLoading = true;
  double fontSize = 16.0;
  final List<ScrollController> _scrollControllers = [];
  String currentTranslation = 'indo_tb';

  @override
  void initState() {
    super.initState();
    currentBookId = widget.bookId ?? 'GEN';
    currentChapterId = widget.chapterId;
    bibleService = BibleService();
    flutterTts = FlutterTts();
    _loadSettings();
    setupTts();
  }

  Future<void> _loadSettings() async {
    await _loadFontSize();
    await _loadCurrentTranslation();
    loadChapterContent();
  }

  Future<void> _loadCurrentTranslation() async {
    final translation = await bibleService.getCurrentTranslation();
    setState(() {
      currentTranslation = translation;
    });
    ref.read(currentTranslationProvider.notifier).state = translation;
  }

  @override
  void dispose() {
    flutterTts.stop();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> setupTts() async {
    await flutterTts.setLanguage('id-ID'); // Indonesian language
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    flutterTts.setCompletionHandler(() {
      if (currentVerseIndex < verses.length - 1) {
        currentVerseIndex++;
        _speakVerse(verses[currentVerseIndex]);
      } else {
        setState(() {
          isPlaying = false;
          currentVerseIndex = 0;
        });
      }
    });
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fontSize = prefs.getDouble('bible_font_size') ?? 16.0;
    });
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bible_font_size', size);
  }

  Future<void> loadChapterContent() async {
    setState(() {
      isLoading = true;
    });

    try {
      final bookData = bibleBooks.firstWhere(
        (book) => book['id'] == currentBookId,
        orElse: () => bibleBooks.first,
      );

      final maxChapters = bookData['chapters'] as int;
      if (currentChapterId > maxChapters) {
        currentChapterId = 1;
      }

      verses = await bibleService.getChapterVerses(
        currentBookId,
        currentChapterId,
        translationId: currentTranslation,
      );

      // Create scroll controllers for each translation
      _scrollControllers.clear();
      _scrollControllers.add(ScrollController());

      // If there's a verse to scroll to, do it after build
      if (widget.scrollToVerse != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToVerse(widget.scrollToVerse!);
        });
      }
    } catch (e) {
      debugPrint('Error loading chapter: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _scrollToVerse(int verseNumber) {
    if (verses.isEmpty || _scrollControllers.isEmpty) return;

    // Find verse index
    final verseIndex = verses.indexWhere((v) => v.verseId == verseNumber);
    if (verseIndex == -1) return;

    // Calculate approximate position
    final estimatedVerseHeight = 60.0; // Estimated average height of a verse
    final offset = verseIndex * estimatedVerseHeight;

    _scrollControllers[0].animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToChapter(String bookId, int chapterId) {
    context.go('/bible-reader?bookId=$bookId&chapterId=$chapterId');
  }

  Future<void> _speakVerse(BibleVerse verse) async {
    if (verse.text.isNotEmpty) {
      await flutterTts.speak('${verse.verseId}. ${verse.text}');
    }
  }

  void _toggleReading() async {
    if (isPlaying) {
      await flutterTts.stop();
      setState(() {
        isPlaying = false;
      });
    } else {
      setState(() {
        isPlaying = true;
        currentVerseIndex = 0;
      });
      _speakVerse(verses[currentVerseIndex]);
    }
  }

  void _showHighlightOptions(BibleVerse verse) {
    final verseKey = '${currentBookId}_${currentChapterId}_${verse.verseId}';
    final highlights = ref.read(highlightStoreProvider);
    final currentColor = highlights[verseKey];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sorot: ${verse.verseId}. ${verse.text}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _buildColorOption(context, verseKey, '#FFEB3B', 'Kuning'),
                  _buildColorOption(context, verseKey, '#4CAF50', 'Hijau'),
                  _buildColorOption(context, verseKey, '#2196F3', 'Biru'),
                  _buildColorOption(context, verseKey, '#F44336', 'Merah'),
                  _buildColorOption(context, verseKey, '#9C27B0', 'Ungu'),
                  if (currentColor != null)
                    _buildRemoveOption(context, verseKey),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(
      BuildContext context, String verseKey, String colorHex, String name) {
    final color =
        Color(int.parse(colorHex.substring(1), radix: 16) | 0xFF000000);
    return InkWell(
      onTap: () {
        ref
            .read(highlightStoreProvider.notifier)
            .addHighlight(verseKey, colorHex);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),
            Text(name),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoveOption(BuildContext context, String verseKey) {
    return InkWell(
      onTap: () {
        ref.read(highlightStoreProvider.notifier).removeHighlight(verseKey);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close),
            ),
            const SizedBox(height: 4),
            const Text('Hapus'),
          ],
        ),
      ),
    );
  }

  void _showVerseActions(BibleVerse verse) {
    final verseKey = '${currentBookId}_${currentChapterId}_${verse.verseId}';
    final isBookmarked =
        ref.read(verseBookmarkProvider.notifier).isVerseBookmarked(verseKey);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ayat ${verse.verseId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(verse.text),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                children: [
                  _buildActionItem(
                    context,
                    Icons.highlight,
                    'Sorot',
                    () {
                      Navigator.pop(context);
                      _showHighlightOptions(verse);
                    },
                  ),
                  _buildActionItem(
                    context,
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    isBookmarked ? 'Tersimpan' : 'Simpan',
                    () {
                      ref
                          .read(verseBookmarkProvider.notifier)
                          .toggleVerseBookmark(verseKey);
                      Navigator.pop(context);
                    },
                  ),
                  _buildActionItem(
                    context,
                    Icons.copy,
                    'Salin',
                    () {
                      // Implement copy functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Ayat tersalin ke clipboard')),
                      );
                      Navigator.pop(context);
                    },
                  ),
                  _buildActionItem(
                    context,
                    Icons.share,
                    'Bagikan',
                    () {
                      // Implement share functionality
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _changeTranslation(String translationId) async {
    setState(() {
      isLoading = true;
      currentTranslation = translationId;
    });

    await bibleService.setCurrentTranslation(translationId);
    ref.read(currentTranslationProvider.notifier).state = translationId;

    loadChapterContent();
  }

  Widget _buildVerseItem(BibleVerse verse) {
    final verseKey = '${currentBookId}_${currentChapterId}_${verse.verseId}';
    final highlightColor = ref.watch(highlightStoreProvider)[verseKey];
    final isBookmarked =
        ref.watch(verseBookmarkProvider.notifier).isVerseBookmarked(verseKey);

    Color? backgroundColor;
    if (highlightColor != null) {
      final color =
          Color(int.parse(highlightColor.substring(1), radix: 16) | 0xFF000000);
      backgroundColor = color.withOpacity(0.3);
    }

    return GestureDetector(
      onLongPress: () => _showVerseActions(verse),
      onTap: () {
        if (isPlaying) {
          flutterTts.stop();
          setState(() {
            isPlaying = false;
            currentVerseIndex = verses.indexOf(verse);
          });
        } else {
          setState(() {
            currentVerseIndex = verses.indexOf(verse);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${verse.verseId}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize - 2,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          verse.text,
                          style: TextStyle(
                            fontSize: fontSize,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (isBookmarked)
                        Icon(
                          Icons.bookmark,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapterKey = '${currentBookId}_$currentChapterId';
    final isChapterBookmarked = ref
        .watch(chapterBookmarkProvider.notifier)
        .isChapterBookmarked(chapterKey);

    final bookData = bibleBooks.firstWhere(
      (book) => book['id'] == currentBookId,
      orElse: () => bibleBooks.first,
    );

    final bookName = bookData['name'] as String;
    final maxChapters = bookData['chapters'] as int;

    // Translation display name
    final translationName = bibleService.availableTranslations.firstWhere(
      (t) => t['id'] == currentTranslation,
      orElse: () => {'name': 'Alkitab'},
    )['name'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$bookName $currentChapterId'),
            Text(
              translationName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Theme.of(context)
                    .appBarTheme
                    .titleTextStyle
                    ?.color
                    ?.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
                isChapterBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () {
              ref
                  .read(chapterBookmarkProvider.notifier)
                  .toggleChapterBookmark(chapterKey);
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Ukuran Font'),
                onTap: () {
                  // Delay to allow menu to close
                  Future.delayed(const Duration(milliseconds: 10), () {
                    _showFontSizeDialog();
                  });
                },
              ),
              PopupMenuItem(
                child: const Text('Ganti Terjemahan'),
                onTap: () {
                  // Delay to allow menu to close
                  Future.delayed(const Duration(milliseconds: 10), () {
                    _showTranslationDialog();
                  });
                },
              ),
              PopupMenuItem(
                onTap: _toggleReading,
                child: Row(
                  children: [
                    Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Text(isPlaying ? 'Hentikan Pembacaan' : 'Mulai Pembacaan'),
                  ],
                ),
              ),
              PopupMenuItem(
                child: const Text('Pergi ke Ayat'),
                onTap: () {
                  // Delay to allow menu to close
                  Future.delayed(const Duration(milliseconds: 10), () {
                    _showGoToVerseDialog();
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Chapter navigation
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: currentChapterId > 1
                      ? () => _navigateToChapter(
                          currentBookId, currentChapterId - 1)
                      : null,
                ),
                DropdownButton<String>(
                  value: currentBookId,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _navigateToChapter(newValue, 1);
                    }
                  },
                  items: bibleBooks.map<DropdownMenuItem<String>>(
                      (Map<String, dynamic> book) {
                    return DropdownMenuItem<String>(
                      value: book['id'] as String,
                      child: Text(book['name'] as String),
                    );
                  }).toList(),
                ),
                DropdownButton<int>(
                  value: currentChapterId,
                  underline: const SizedBox(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      _navigateToChapter(currentBookId, newValue);
                    }
                  },
                  items: List<DropdownMenuItem<int>>.generate(
                    maxChapters,
                    (i) => DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text('Pasal ${i + 1}'),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: currentChapterId < maxChapters
                      ? () => _navigateToChapter(
                          currentBookId, currentChapterId + 1)
                      : null,
                ),
              ],
            ),
          ),
          // Bible content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : verses.isEmpty
                    ? const Center(child: Text('Tidak ada ayat yang ditemukan'))
                    : ListView.builder(
                        controller: _scrollControllers.isNotEmpty
                            ? _scrollControllers[0]
                            : null,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: verses.length,
                        itemBuilder: (context, index) {
                          return _buildVerseItem(verses[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempFontSize = fontSize;
        return AlertDialog(
          title: const Text('Ukuran Font'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: tempFontSize,
                    min: 12.0,
                    max: 28.0,
                    divisions: 8,
                    label: tempFontSize.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        tempFontSize = value;
                      });
                    },
                  ),
                  Text(
                    'Teks Contoh',
                    style: TextStyle(fontSize: tempFontSize),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  fontSize = tempFontSize;
                });
                _saveFontSize(tempFontSize);
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showTranslationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Terjemahan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: bibleService.availableTranslations.map((translation) {
              final isSelected = translation['id'] == currentTranslation;
              return ListTile(
                title: Text(translation['name'] as String),
                subtitle: Text(translation['language'] as String),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  _changeTranslation(translation['id'] as String);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  void _showGoToVerseDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Pergi ke Ayat'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nomor Ayat',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final verse = int.tryParse(controller.text);
                if (verse != null && verse > 0) {
                  _scrollToVerse(verse);
                }
                Navigator.pop(context);
              },
              child: const Text('Pergi'),
            ),
          ],
        );
      },
    );
  }
}
