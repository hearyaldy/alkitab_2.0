import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/models/bookmark_model.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';
import 'package:alkitab_2_0/services/bible_service.dart';
import 'package:alkitab_2_0/providers/highlight_provider.dart';
import 'package:alkitab_2_0/providers/bookmark_providers.dart';

// Current Bible translation provider
final currentTranslationProvider = StateProvider<String>((ref) => 'indo_tb');

// Audio settings providers
final audioVoiceProvider = StateProvider<String>((ref) => 'female');
final audioSpeedProvider = StateProvider<double>((ref) => 0.5);
final audioPitchProvider = StateProvider<double>((ref) => 1.0);
final audioVolumeProvider = StateProvider<double>((ref) => 1.0);

// Color palette for the reading surface, selectable independent of the
// app/system dark mode via the "Reading Theme" menu option.
class _ReaderPalette {
  final Color background;
  final Color panelBackground;
  final Color borderColor;
  final Color accentColor;
  final Color bodyTextColor;

  const _ReaderPalette({
    required this.background,
    required this.panelBackground,
    required this.borderColor,
    required this.accentColor,
    required this.bodyTextColor,
  });
}

const _sepiaPalette = _ReaderPalette(
  background: Color(0xFFFAF9F6),
  panelBackground: Color(0xFFF8F6F0),
  borderColor: Color(0x338B4513),
  accentColor: Color(0xFF8B4513),
  bodyTextColor: Color(0xFF2F2F2F),
);

const _lightPalette = _ReaderPalette(
  background: Colors.white,
  panelBackground: Color(0xFFF5F5F5),
  borderColor: Color(0xFFE0E0E0),
  accentColor: Color(0xFF1E3A8A),
  bodyTextColor: Color(0xFF1F1F1F),
);

const _darkPalette = _ReaderPalette(
  background: Color(0xFF121212),
  panelBackground: Color(0xFF1E1E1E),
  borderColor: Colors.white12,
  accentColor: Color(0xFFFFB74D),
  bodyTextColor: Colors.white70,
);

_ReaderPalette _paletteFor(String readingTheme) {
  switch (readingTheme) {
    case 'light':
      return _lightPalette;
    case 'dark':
      return _darkPalette;
    case 'sepia':
    default:
      return _sepiaPalette;
  }
}

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
  String selectedVoice = 'female';
  double speechRate = 0.5;
  double speechPitch = 1.0;
  double speechVolume = 1.0;
  List<String> availableVoices = [];
  Map<String, dynamic>? bibleMetadata;
  String readingTheme = 'sepia';
  Set<int> _selectedVerses = {};

  bool get _isSelectionMode => _selectedVerses.isNotEmpty;

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
    await _loadReadingTheme();
    await _loadCurrentTranslation();
    loadChapterContent();
  }

  Future<void> _loadCurrentTranslation() async {
    final translation = bibleService.getCurrentTranslation();
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
    await _loadAudioSettings();
    await _applyAudioSettings();
    await _getAvailableVoices();

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

  Future<void> _getAvailableVoices() async {
    try {
      final voices = await flutterTts.getVoices;
      if (voices is List) {
        availableVoices = voices
            .map((voice) => voice['name']?.toString() ?? voice.toString())
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting voices: $e');
      availableVoices = ['Default'];
    }
  }

  Future<void> _loadAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedVoice = prefs.getString('audio_voice') ?? 'female';
      speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      speechPitch = prefs.getDouble('speech_pitch') ?? 1.0;
      speechVolume = prefs.getDouble('speech_volume') ?? 1.0;
    });
  }

  Future<void> _saveAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_voice', selectedVoice);
    await prefs.setDouble('speech_rate', speechRate);
    await prefs.setDouble('speech_pitch', speechPitch);
    await prefs.setDouble('speech_volume', speechVolume);
  }

  Future<void> _applyAudioSettings() async {
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setVolume(speechVolume);
    await flutterTts.setPitch(speechPitch);
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

  Future<void> _loadReadingTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      readingTheme = prefs.getString('bible_reading_theme') ?? 'sepia';
    });
  }

  Future<void> _saveReadingTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bible_reading_theme', theme);
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
      );

      // Load metadata for the current translation
      bibleMetadata = await bibleService.getCurrentTranslationMetadata();

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

    // Calculate approximate position (header panel + one row per verse)
    const headerOffset = 140.0;
    const estimatedVerseHeight = 70.0;
    final offset = headerOffset + verseIndex * estimatedVerseHeight;

    _scrollControllers[0].animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToChapter(String bookId, int chapterId) {
    setState(() {
      currentBookId = bookId;
      currentChapterId = chapterId;
      _selectedVerses = {};
    });
    loadChapterContent();
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

  // --- Selection mode -------------------------------------------------

  void _startSelection(int verseId) {
    setState(() {
      _selectedVerses = {verseId};
    });
  }

  void _toggleVerseSelection(int verseId) {
    setState(() {
      final updated = Set<int>.from(_selectedVerses);
      if (updated.contains(verseId)) {
        updated.remove(verseId);
      } else {
        updated.add(verseId);
      }
      _selectedVerses = updated;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedVerses = {};
    });
  }

  void _showBatchActionsSheet() {
    final selected = verses
        .where((v) => _selectedVerses.contains(v.verseId))
        .toList()
      ..sort((a, b) => a.verseId.compareTo(b.verseId));
    if (selected.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('Bookmark Selected'),
                onTap: () async {
                  Navigator.pop(context);
                  await _bookmarkVerses(selected);
                  _clearSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy_outlined),
                title: const Text('Copy Selected'),
                onTap: () {
                  Navigator.pop(context);
                  _copySelectedVerses(selected);
                  _clearSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share Selected'),
                onTap: () {
                  Navigator.pop(context);
                  _shareSelectedVerses(selected);
                  _clearSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel Selection'),
                onTap: () {
                  Navigator.pop(context);
                  _clearSelection();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookmarkVerses(List<BibleVerse> selected) async {
    final bookName = getBookNameById(currentBookId);
    for (final verse in selected) {
      await ref.read(bookmarkOperationsProvider.notifier).addBookmark(
            BookmarkModel(
              id: '',
              userId: '',
              type: 'bible',
              bookmarkType: 'bible_verse',
              title: '$bookName $currentChapterId:${verse.verseId}',
              verseReference: '$bookName $currentChapterId:${verse.verseId}',
              verseText: verse.text,
              bookId: currentBookId,
              chapterId: currentChapterId,
              verseId: verse.verseId,
            ),
          );
    }
    ref.invalidate(bookmarksProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} verse(s) bookmarked')),
      );
    }
  }

  void _copySelectedVerses(List<BibleVerse> selected) {
    final bookName = getBookNameById(currentBookId);
    final body = selected.map((v) => '${v.verseId}. ${v.text}').join('\n');
    final reference = selected.length == 1
        ? '$bookName $currentChapterId:${selected.first.verseId}'
        : '$bookName $currentChapterId:${selected.first.verseId}-${selected.last.verseId}';
    Clipboard.setData(ClipboardData(text: '$body\n\n- $reference'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verses copied to clipboard')),
    );
  }

  void _shareSelectedVerses(List<BibleVerse> selected) {
    final bookName = getBookNameById(currentBookId);
    final body = selected.map((v) => '${v.verseId}. ${v.text}').join('\n');
    final reference = selected.length == 1
        ? '$bookName $currentChapterId:${selected.first.verseId}'
        : '$bookName $currentChapterId:${selected.first.verseId}-${selected.last.verseId}';
    Share.share('$body\n\n- $reference\n\nFrom Alkitab 2.0');
  }

  // --- Highlights -------------------------------------------------------

  void _showHighlightOptions(BibleVerse verse, HighlightModel? currentHighlight) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Highlight: ${verse.verseId}. ${verse.text}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final colorHex in HighlightColors.all())
                    _buildHighlightSwatch(
                      sheetContext,
                      verse,
                      colorHex,
                      currentHighlight?.colorHex == colorHex,
                    ),
                  if (currentHighlight != null)
                    _buildRemoveHighlightOption(sheetContext, verse),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighlightSwatch(
    BuildContext sheetContext,
    BibleVerse verse,
    String colorHex,
    bool isSelected,
  ) {
    final color = Color(int.parse(colorHex, radix: 16));
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await addHighlight(
          ref,
          bookId: currentBookId,
          chapterId: currentChapterId,
          verseNumber: verse.verseId,
          colorHex: colorHex,
          verseText: verse.text,
        );
        Navigator.pop(sheetContext);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 3)
              : null,
        ),
      ),
    );
  }

  Widget _buildRemoveHighlightOption(BuildContext sheetContext, BibleVerse verse) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await removeHighlight(
          ref,
          bookId: currentBookId,
          chapterId: currentChapterId,
          verseNumber: verse.verseId,
        );
        Navigator.pop(sheetContext);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 18),
      ),
    );
  }

  // --- Bookmarks ----------------------------------------------------------

  Future<void> _toggleVerseBookmark(BibleVerse verse, BookmarkModel? existing) async {
    if (existing != null) {
      await ref.read(bookmarkOperationsProvider.notifier).deleteBookmark(existing.id);
    } else {
      final bookName = getBookNameById(currentBookId);
      await ref.read(bookmarkOperationsProvider.notifier).addBookmark(
            BookmarkModel(
              id: '',
              userId: '',
              type: 'bible',
              bookmarkType: 'bible_verse',
              title: '$bookName $currentChapterId:${verse.verseId}',
              verseReference: '$bookName $currentChapterId:${verse.verseId}',
              verseText: verse.text,
              bookId: currentBookId,
              chapterId: currentChapterId,
              verseId: verse.verseId,
            ),
          );
    }
    ref.invalidate(bookmarksProvider);
  }

  Future<void> _toggleChapterBookmark(BookmarkModel? existing) async {
    if (existing != null) {
      await ref.read(bookmarkOperationsProvider.notifier).deleteBookmark(existing.id);
    } else {
      final bookName = getBookNameById(currentBookId);
      await ref.read(bookmarkOperationsProvider.notifier).addBookmark(
            BookmarkModel(
              id: '',
              userId: '',
              type: 'bible',
              bookmarkType: 'bible_chapter',
              title: '$bookName $currentChapterId',
              verseReference: '$bookName $currentChapterId',
              bookId: currentBookId,
              chapterId: currentChapterId,
              verseId: null,
            ),
          );
    }
    ref.invalidate(bookmarksProvider);
  }

  // --- Verse action sheet ---------------------------------------------

  void _showVerseActions(
    BibleVerse verse, {
    required BookmarkModel? existingBookmark,
    required HighlightModel? existingHighlight,
  }) {
    final isBookmarked = existingBookmark != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header section
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.orange[200]
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Verse ${verse.verseId}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[900]
                                  : Colors.orange[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close,
                              color:
                                  isDark ? Colors.white54 : Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        verse.text,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.87)
                              : Colors.grey[800],
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildModernActionItem(
                      context,
                      Icons.highlight_outlined,
                      'Highlight Verse',
                      'Add a highlight color to this verse',
                      Colors.amber,
                      () {
                        Navigator.pop(context);
                        _showHighlightOptions(verse, existingHighlight);
                      },
                    ),
                    _buildModernActionItem(
                      context,
                      isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_add_outlined,
                      isBookmarked ? 'Remove Bookmark' : 'Save Bookmark',
                      isBookmarked
                          ? 'Remove from your bookmark list'
                          : 'Save to your bookmark list',
                      isBookmarked ? Colors.green : Colors.blue,
                      () async {
                        Navigator.pop(context);
                        await _toggleVerseBookmark(verse, existingBookmark);
                      },
                    ),
                    _buildModernActionItem(
                      context,
                      Icons.note_add_outlined,
                      'Add Note',
                      'Write a personal note for this verse',
                      Colors.purple,
                      () {
                        Navigator.pop(context);
                        _showAddNoteDialog(verse);
                      },
                    ),
                    _buildModernActionItem(
                      context,
                      Icons.content_copy_outlined,
                      'Copy Text',
                      'Copy verse to clipboard',
                      Colors.grey[600]!,
                      () {
                        final bookName = getBookNameById(currentBookId);
                        final verseText =
                            '${verse.text}\n\n- $bookName $currentChapterId:${verse.verseId}';
                        Clipboard.setData(ClipboardData(text: verseText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Verse copied to clipboard'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                    _buildModernActionItem(
                      context,
                      Icons.share_outlined,
                      'Share',
                      'Share verse to another app',
                      Colors.indigo,
                      () {
                        final bookName = getBookNameById(currentBookId);
                        final verseText =
                            '${verse.text}\n\n- $bookName $currentChapterId:${verse.verseId}\n\nFrom Alkitab 2.0';
                        Share.share(verseText);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              // Bottom padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernActionItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey[200]!,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddNoteDialog(BibleVerse verse) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.note_add_outlined,
                        color: Colors.purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add Note',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Verse reference
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${getBookNameById(currentBookId)} $currentChapterId:${verse.verseId}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        verse.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Note input
                Text(
                  'Your Note',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write a personal note for this verse...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.purple,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (noteController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Note cannot be empty'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          // Save note to local storage for now
                          // TODO: Integrate with note service
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Note saved successfully'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _changeTranslation(String translationId) async {
    setState(() {
      isLoading = true;
      currentTranslation = translationId;
    });

    bibleService.setCurrentTranslation(translationId);
    ref.read(currentTranslationProvider.notifier).state = translationId;

    loadChapterContent();
  }

  // --- Chapter / book picker --------------------------------------------

  void _showChapterPicker() {
    final bookData = bibleBooks.firstWhere(
      (b) => b['id'] == currentBookId,
      orElse: () => bibleBooks.first,
    );
    final maxChapters = bookData['chapters'] as int;
    final bookName = bookData['name'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bookName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showBookPicker();
                        },
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Change Book'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: maxChapters,
                    itemBuilder: (context, index) {
                      final chapterNum = index + 1;
                      final isCurrent = chapterNum == currentChapterId;
                      final colorScheme = Theme.of(context).colorScheme;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToChapter(currentBookId, chapterNum);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isCurrent
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$chapterNum',
                            style: TextStyle(
                              color: isCurrent
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBookPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Book',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: bibleBooks.length,
                    itemBuilder: (context, index) {
                      final book = bibleBooks[index];
                      final isCurrent = book['id'] == currentBookId;
                      return ListTile(
                        title: Text(book['name'] as String),
                        trailing: isCurrent
                            ? Icon(Icons.check,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToChapter(book['id'] as String, 1);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Verse list --------------------------------------------------------

  Widget _buildVerseList(
    Map<int, HighlightModel> highlightsByVerse,
    Map<int, BookmarkModel> verseBookmarksByVerse,
  ) {
    if (verses.isEmpty) {
      return const Center(child: Text('No verses found'));
    }

    final bookData = bibleBooks.firstWhere(
      (book) => book['id'] == currentBookId,
      orElse: () => bibleBooks.first,
    );
    final bookName = bookData['name'] as String;
    final palette = _paletteFor(readingTheme);

    return Container(
      color: palette.background,
      child: ListView.builder(
        controller:
            _scrollControllers.isNotEmpty ? _scrollControllers[0] : null,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: verses.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildChapterHeading(bookName, palette);
          }
          if (index == verses.length + 1) {
            return _buildChapterFooting(bookName, palette);
          }

          final verse = verses[index - 1];
          final highlight = highlightsByVerse[verse.verseId];
          final bookmark = verseBookmarksByVerse[verse.verseId];
          final isSelected = _selectedVerses.contains(verse.verseId);
          return _buildVerseRow(verse, highlight, bookmark, isSelected, palette);
        },
      ),
    );
  }

  Widget _buildChapterHeading(String bookName, _ReaderPalette palette) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: palette.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        children: [
          Text(
            bookName,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: fontSize + 8,
              fontWeight: FontWeight.bold,
              color: palette.accentColor,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Chapter $currentChapterId',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: fontSize + 2,
              fontWeight: FontWeight.w500,
              color: palette.accentColor.withValues(alpha: 0.8),
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterFooting(String bookName, _ReaderPalette palette) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: palette.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        children: [
          Text(
            '- $bookName $currentChapterId -',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: fontSize - 2,
              fontWeight: FontWeight.w500,
              color: palette.accentColor.withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (bibleMetadata != null) ...[
            Text(
              bibleMetadata!['name'] ?? 'Bible',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: fontSize - 4,
                fontStyle: FontStyle.italic,
                color: palette.bodyTextColor.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (bibleMetadata!['publisher'] != null &&
                bibleMetadata!['publisher'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  bibleMetadata!['publisher'],
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: fontSize - 5,
                    color: palette.bodyTextColor.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (bibleMetadata!['year'] != null &&
                bibleMetadata!['year'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  bibleMetadata!['year'],
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: fontSize - 5,
                    color: palette.bodyTextColor.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else
            Text(
              'Bible in the Malay Language',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: fontSize - 4,
                fontStyle: FontStyle.italic,
                color: palette.bodyTextColor.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildVerseRow(
    BibleVerse verse,
    HighlightModel? highlight,
    BookmarkModel? bookmark,
    bool isSelected,
    _ReaderPalette palette,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color rowBackground = Colors.transparent;
    if (isSelected) {
      rowBackground = colorScheme.primary.withValues(alpha: 0.15);
    } else if (highlight != null) {
      rowBackground =
          Color(int.parse(highlight.colorHex, radix: 16)).withValues(alpha: 0.55);
    }

    final isCurrentlyReading = isPlaying &&
        verses.isNotEmpty &&
        currentVerseIndex < verses.length &&
        verses[currentVerseIndex].verseId == verse.verseId;

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleVerseSelection(verse.verseId);
          return;
        }
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
      onLongPress: () {
        if (_isSelectionMode) {
          _toggleVerseSelection(verse.verseId);
        } else {
          _startSelection(verse.verseId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: rowBackground,
          borderRadius: BorderRadius.circular(10),
          border: isCurrentlyReading
              ? Border.all(color: palette.accentColor, width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (_isSelectionMode) {
                  _toggleVerseSelection(verse.verseId);
                } else {
                  _showVerseActions(
                    verse,
                    existingBookmark: bookmark,
                    existingHighlight: highlight,
                  );
                }
              },
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : palette.accentColor,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                    : Text(
                        '${verse.verseId}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.accentColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                verse.text,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: fontSize,
                  height: 1.6,
                  color: palette.bodyTextColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (bookmark != null)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Icon(Icons.bookmark, size: 16, color: palette.accentColor),
              ),
          ],
        ),
      ),
    );
  }

  // --- Audio mini-player ---------------------------------------------

  Widget _buildAudioMiniPlayer() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCurrentVerse = verses.isNotEmpty && currentVerseIndex < verses.length;
    final currentVerse = hasCurrentVerse ? verses[currentVerseIndex] : null;
    final bookName = getBookNameById(currentBookId);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: child,
      ),
      child: !isPlaying || currentVerse == null
          ? const SizedBox.shrink(key: ValueKey('mini-player-hidden'))
          : Material(
              key: const ValueKey('mini-player-visible'),
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.pause_circle_filled,
                        color: colorScheme.onPrimaryContainer,
                        size: 36,
                      ),
                      onPressed: _toggleReading,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$bookName $currentChapterId:${currentVerse.verseId}',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            currentVerse.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onPrimaryContainer),
                      onPressed: () {
                        flutterTts.stop();
                        setState(() => isPlaying = false);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBottomBarAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? colorScheme.onSurface.withValues(alpha: 0.35)
        : highlighted
            ? colorScheme.primary
            : colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookData = bibleBooks.firstWhere(
      (book) => book['id'] == currentBookId,
      orElse: () => bibleBooks.first,
    );

    final bookName = bookData['name'] as String;
    final maxChapters = bookData['chapters'] as int;

    // Translation display name
    final translationName = bibleService.availableTranslations.firstWhere(
      (t) => t['id'] == currentTranslation,
      orElse: () => {'name': 'Bible'},
    )['name'];

    // Real, synced bookmarks (fixes the earlier local-only bookmark store
    // that never showed up in the Bookmarks screen or Firestore correctly).
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final bookmarksList = bookmarksAsync.value ?? <BookmarkModel>[];
    BookmarkModel? chapterBookmark;
    final verseBookmarksByVerse = <int, BookmarkModel>{};
    for (final b in bookmarksList) {
      if (!b.isBibleBookmark ||
          b.bookId != currentBookId ||
          b.chapterId != currentChapterId) {
        continue;
      }
      if (b.verseId == null) {
        chapterBookmark = b;
      } else {
        verseBookmarksByVerse[b.verseId!] = b;
      }
    }
    final isChapterBookmarked = chapterBookmark != null;

    // Real, synced highlights (fixes the earlier local-only highlight
    // store that never showed up on the Highlights screen).
    final chapterHighlightsAsync = ref
        .watch(chapterHighlightsProvider((currentBookId, currentChapterId)));
    final highlightsByVerse = <int, HighlightModel>{};
    for (final h in (chapterHighlightsAsync.value ?? <HighlightModel>[])) {
      highlightsByVerse[h.verseNumber] = h;
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                  tooltip: 'Cancel selection',
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/bible'),
                  tooltip: 'Back',
                ),
          title: _isSelectionMode
              ? Text('${_selectedVerses.length} selected')
              : GestureDetector(
                  onTap: _showChapterPicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$bookName $currentChapterId',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.expand_more, size: 20),
                        ],
                      ),
                      Text(
                        translationName ?? 'Bible',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context)
                              .appBarTheme
                              .titleTextStyle
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
          actions: _isSelectionMode
              ? const []
              : [
                  IconButton(
                    icon: Icon(isChapterBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border),
                    onPressed: () => _toggleChapterBookmark(chapterBookmark),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: isPlaying ? Colors.green : null,
                    ),
                    onPressed: _toggleReading,
                    tooltip: isPlaying ? 'Stop Reading' : 'Start Reading',
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Font Size'),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 10), () {
                            _showFontSizeDialog();
                          });
                        },
                      ),
                      PopupMenuItem(
                        child: const Text('Reading Theme'),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 10), () {
                            _showReadingThemeDialog();
                          });
                        },
                      ),
                      PopupMenuItem(
                        child: const Text('Change Translation'),
                        onTap: () {
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
                            Text(isPlaying ? 'Stop Reading' : 'Start Reading'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        child: const Text('Audio Settings'),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 10), () {
                            _showAudioSettingsDialog();
                          });
                        },
                      ),
                      PopupMenuItem(
                        child: const Text('Go to Verse'),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 10), () {
                            _showGoToVerseDialog();
                          });
                        },
                      ),
                    ],
                  ),
                ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildVerseList(highlightsByVerse, verseBookmarksByVerse),
        floatingActionButton: _isSelectionMode
            ? FloatingActionButton.extended(
                onPressed: _showBatchActionsSheet,
                icon: const Icon(Icons.checklist),
                label: Text('${_selectedVerses.length} selected'),
              )
            : null,
        bottomNavigationBar: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAudioMiniPlayer(),
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildBottomBarAction(
                          icon: Icons.chevron_left,
                          label: 'Previous',
                          onTap: currentChapterId > 1
                              ? () => _navigateToChapter(
                                  currentBookId, currentChapterId - 1)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: _buildBottomBarAction(
                          icon: Icons.menu_book_outlined,
                          label: 'Ch. $currentChapterId',
                          onTap: _showChapterPicker,
                          highlighted: true,
                        ),
                      ),
                      Expanded(
                        child: _buildBottomBarAction(
                          icon: Icons.chevron_right,
                          label: 'Next',
                          onTap: currentChapterId < maxChapters
                              ? () => _navigateToChapter(
                                  currentBookId, currentChapterId + 1)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempFontSize = fontSize;
        return AlertDialog(
          title: const Text('Font Size'),
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
                    'Sample Text',
                    style: TextStyle(fontSize: tempFontSize),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  fontSize = tempFontSize;
                });
                _saveFontSize(tempFontSize);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showReadingThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempTheme = readingTheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reading Theme'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Sepia'),
                    subtitle: const Text('Warm, paper-like reading background'),
                    value: 'sepia',
                    groupValue: tempTheme,
                    onChanged: (value) {
                      setState(() => tempTheme = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Light'),
                    subtitle: const Text('Clean white background'),
                    value: 'light',
                    groupValue: tempTheme,
                    onChanged: (value) {
                      setState(() => tempTheme = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Dark'),
                    subtitle: const Text('Dark background for low-light reading'),
                    value: 'dark',
                    groupValue: tempTheme,
                    onChanged: (value) {
                      setState(() => tempTheme = value!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      readingTheme = tempTheme;
                    });
                    _saveReadingTheme(tempTheme);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTranslationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Translation'),
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
              child: const Text('Cancel'),
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
          title: const Text('Go to Verse'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Verse Number',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final verse = int.tryParse(controller.text);
                if (verse != null && verse > 0) {
                  _scrollToVerse(verse);
                }
                Navigator.pop(context);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _showAudioSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempSpeechRate = speechRate;
        double tempSpeechPitch = speechPitch;
        double tempSpeechVolume = speechVolume;
        String tempSelectedVoice = selectedVoice;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Audio Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voice Selection
                    const Text('Select Voice:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Female'),
                            value: 'female',
                            groupValue: tempSelectedVoice,
                            onChanged: (value) {
                              setState(() {
                                tempSelectedVoice = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Male'),
                            value: 'male',
                            groupValue: tempSelectedVoice,
                            onChanged: (value) {
                              setState(() {
                                tempSelectedVoice = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Speech Rate
                    const Text('Reading Speed:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Slow'),
                        Expanded(
                          child: Slider(
                            value: tempSpeechRate,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            label: '${(tempSpeechRate * 100).round()}%',
                            onChanged: (value) {
                              setState(() {
                                tempSpeechRate = value;
                              });
                            },
                          ),
                        ),
                        const Text('Fast'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Speech Pitch
                    const Text('Voice Pitch:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Low'),
                        Expanded(
                          child: Slider(
                            value: tempSpeechPitch,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            label: tempSpeechPitch.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                tempSpeechPitch = value;
                              });
                            },
                          ),
                        ),
                        const Text('High'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Speech Volume
                    const Text('Volume:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Low'),
                        Expanded(
                          child: Slider(
                            value: tempSpeechVolume,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            label: '${(tempSpeechVolume * 100).round()}%',
                            onChanged: (value) {
                              setState(() {
                                tempSpeechVolume = value;
                              });
                            },
                          ),
                        ),
                        const Text('High'),
                      ],
                    ),

                    // Test Audio Button
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await flutterTts.setSpeechRate(tempSpeechRate);
                          await flutterTts.setVolume(tempSpeechVolume);
                          await flutterTts.setPitch(tempSpeechPitch);
                          // Spoken by the Indonesian ('id-ID') TTS voice, so this
                          // sample phrase stays in Indonesian regardless of UI language.
                          await flutterTts.speak(
                              'Ini adalah contoh suara pembacaan Alkitab');
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Test Voice'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    setState(() {
                      selectedVoice = tempSelectedVoice;
                      speechRate = tempSpeechRate;
                      speechPitch = tempSpeechPitch;
                      speechVolume = tempSpeechVolume;
                    });
                    await _saveAudioSettings();
                    await _applyAudioSettings();
                    navigator.pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
