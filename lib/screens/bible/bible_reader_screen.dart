import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:alkitab_2_0/models/bible_model.dart'; // ✅ Make sure this file exists

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String? bookId;
  final int chapterId;

  const BibleReaderScreen({super.key, this.bookId, this.chapterId = 1});

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

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.bookId ?? 'genesis';
    _currentChapter = widget.chapterId;
    _versesFuture = _fetchVerses();
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
    final bookNum = _getBookIndex(_currentBookId);

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

  @override
  Widget build(BuildContext context) {
    final bookName = _getBookName(_currentBookId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bible'),
        ),
        title: Text('$bookName $_currentChapter ($_currentVersion)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.font_download),
            onPressed: () => setState(() => _showSettings = !_showSettings),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'version') _showVersionDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'version',
                child: Row(
                  children: [
                    Icon(Icons.translate, size: 20),
                    SizedBox(width: 8),
                    Text('Tukar Versi'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSettings) _buildSettingsPanel(),
          _buildChapterNavigation(),
          Expanded(
            child: FutureBuilder<List<BibleVerse>>(
              future: _versesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  final verses = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: verses.length,
                    itemBuilder: (context, index) => _buildVerseItem(
                      verses[index].verseNumber,
                      verses[index].text,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() => Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.grey[100],
        child: Row(
          children: [
            const Text('Saiz Teks:'),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 12.0,
                max: 28.0,
                divisions: 8,
                onChanged: (value) => setState(() => _fontSize = value),
              ),
            ),
            Text(_fontSize.toInt().toString()),
          ],
        ),
      );

  Widget _buildChapterNavigation() => Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: _currentChapter > 1
                  ? () => setState(() {
                        _currentChapter--;
                        _versesFuture = _fetchVerses();
                      })
                  : null,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showChapterSelector,
              child: Text(
                'Fasal $_currentChapter',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: _currentChapter < _getMaxChapters(_currentBookId)
                  ? () => setState(() {
                        _currentChapter++;
                        _versesFuture = _fetchVerses();
                      })
                  : null,
            ),
          ],
        ),
      );

  Widget _buildVerseItem(int verseNumber, String verseText) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$verseNumber ',
                style: TextStyle(
                  fontSize: _fontSize - 2,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              TextSpan(
                text: verseText,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: Colors.black,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );

  void _showVersionDialog() => showDialog(
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

  void _showChapterSelector() => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pilih Fasal - ${_getBookName(_currentBookId)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
              ),
              itemCount: _getMaxChapters(_currentBookId),
              itemBuilder: (context, index) {
                final chapterNumber = index + 1;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentChapter = chapterNumber;
                      _versesFuture = _fetchVerses();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _currentChapter == chapterNumber
                          ? Colors.blue
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        chapterNumber.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _currentChapter == chapterNumber
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

  /// MAPS — Same as previous reply, but updated with Malay names
  int _getBookIndex(String bookId) => _bookIndexMap[bookId] ?? 1;
  int _getMaxChapters(String bookId) => _chapterCountMap[bookId] ?? 1;
  String _getBookName(String bookId) => _bookNameMap[bookId] ?? bookId;

  final Map<String, int> _bookIndexMap = {
    'genesis': 1,
    'exodus': 2,
    'leviticus': 3,
    'numbers': 4,
    'deuteronomy': 5,
    'joshua': 6,
    'judges': 7,
    'ruth': 8,
    '1_samuel': 9,
    '2_samuel': 10,
    '1_kings': 11,
    '2_kings': 12,
    '1_chronicles': 13,
    '2_chronicles': 14,
    'ezra': 15,
    'nehemiah': 16,
    'esther': 17,
    'job': 18,
    'psalms': 19,
    'proverbs': 20,
    'ecclesiastes': 21,
    'song_of_solomon': 22,
    'isaiah': 23,
    'jeremiah': 24,
    'lamentations': 25,
    'ezekiel': 26,
    'daniel': 27,
    'hosea': 28,
    'joel': 29,
    'amos': 30,
    'obadiah': 31,
    'jonah': 32,
    'micah': 33,
    'nahum': 34,
    'habakkuk': 35,
    'zephaniah': 36,
    'haggai': 37,
    'zechariah': 38,
    'malachi': 39,
    'matt': 40,
    'mark': 41,
    'luke': 42,
    'john': 43,
    'acts': 44,
    'romans': 45,
    '1_corinthians': 46,
    '2_corinthians': 47,
    'galatians': 48,
    'ephesians': 49,
    'philippians': 50,
    'colossians': 51,
    '1_thessalonians': 52,
    '2_thessalonians': 53,
    '1_timothy': 54,
    '2_timothy': 55,
    'titus': 56,
    'philemon': 57,
    'hebrews': 58,
    'james': 59,
    '1_peter': 60,
    '2_peter': 61,
    '1_john': 62,
    '2_john': 63,
    '3_john': 64,
    'jude': 65,
    'revelation': 66
  };

  final Map<String, String> _bookNameMap = {
    'genesis': 'Kejadian',
    'exodus': 'Keluaran',
    'leviticus': 'Imamat',
    'numbers': 'Bilangan',
    'deuteronomy': 'Ulangan',
    'joshua': 'Yosua',
    'judges': 'Hakim-Hakim',
    'ruth': 'Rut',
    '1_samuel': '1 Samuel',
    '2_samuel': '2 Samuel',
    '1_kings': '1 Raja-Raja',
    '2_kings': '2 Raja-Raja',
    '1_chronicles': '1 Tawarikh',
    '2_chronicles': '2 Tawarikh',
    'ezra': 'Ezra',
    'nehemiah': 'Nehemia',
    'esther': 'Ester',
    'job': 'Ayub',
    'psalms': 'Mazmur',
    'proverbs': 'Amsal',
    'ecclesiastes': 'Pengkhotbah',
    'song_of_solomon': 'Kidung Agung',
    'isaiah': 'Yesaya',
    'jeremiah': 'Yeremia',
    'lamentations': 'Ratapan',
    'ezekiel': 'Yehezkiel',
    'daniel': 'Daniel',
    'hosea': 'Hosea',
    'joel': 'Yoel',
    'amos': 'Amos',
    'obadiah': 'Obaja',
    'jonah': 'Yunus',
    'micah': 'Mikha',
    'nahum': 'Nahum',
    'habakkuk': 'Habakuk',
    'zephaniah': 'Zefanya',
    'haggai': 'Hagai',
    'zechariah': 'Zakharia',
    'malachi': 'Maleakhi',
    'matt': 'Matius',
    'mark': 'Markus',
    'luke': 'Lukas',
    'john': 'Yohanes',
    'acts': 'Kisah Para Rasul',
    'romans': 'Roma',
    '1_corinthians': '1 Korintus',
    '2_corinthians': '2 Korintus',
    'galatians': 'Galatia',
    'ephesians': 'Efesus',
    'philippians': 'Filipi',
    'colossians': 'Kolose',
    '1_thessalonians': '1 Tesalonika',
    '2_thessalonians': '2 Tesalonika',
    '1_timothy': '1 Timotius',
    '2_timothy': '2 Timotius',
    'titus': 'Titus',
    'philemon': 'Filemon',
    'hebrews': 'Ibrani',
    'james': 'Yakobus',
    '1_peter': '1 Petrus',
    '2_peter': '2 Petrus',
    '1_john': '1 Yohanes',
    '2_john': '2 Yohanes',
    '3_john': '3 Yohanes',
    'jude': 'Yudas',
    'revelation': 'Wahyu'
  };

  final Map<String, int> _chapterCountMap = {
    'genesis': 50,
    'exodus': 40,
    'leviticus': 27,
    'numbers': 36,
    'deuteronomy': 34,
    'joshua': 24,
    'judges': 21,
    'ruth': 4,
    '1_samuel': 31,
    '2_samuel': 24,
    '1_kings': 22,
    '2_kings': 25,
    '1_chronicles': 29,
    '2_chronicles': 36,
    'ezra': 10,
    'nehemiah': 13,
    'esther': 10,
    'job': 42,
    'psalms': 150,
    'proverbs': 31,
    'ecclesiastes': 12,
    'song_of_solomon': 8,
    'isaiah': 66,
    'jeremiah': 52,
    'lamentations': 5,
    'ezekiel': 48,
    'daniel': 12,
    'hosea': 14,
    'joel': 3,
    'amos': 9,
    'obadiah': 1,
    'jonah': 4,
    'micah': 7,
    'nahum': 3,
    'habakkuk': 3,
    'zephaniah': 3,
    'haggai': 2,
    'zechariah': 14,
    'malachi': 4,
    'matt': 28,
    'mark': 16,
    'luke': 24,
    'john': 21,
    'acts': 28,
    'romans': 16,
    '1_corinthians': 16,
    '2_corinthians': 13,
    'galatians': 6,
    'ephesians': 6,
    'philippians': 4,
    'colossians': 4,
    '1_thessalonians': 5,
    '2_thessalonians': 3,
    '1_timothy': 6,
    '2_timothy': 4,
    'titus': 3,
    'philemon': 1,
    'hebrews': 13,
    'james': 5,
    '1_peter': 5,
    '2_peter': 3,
    '1_john': 5,
    '2_john': 1,
    '3_john': 1,
    'jude': 1,
    'revelation': 22
  };
}
