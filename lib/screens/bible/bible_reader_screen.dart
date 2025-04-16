// Updated with search + bottom sheet + modern verse styling
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:alkitab_2_0/models/bible_model.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';

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

  @override
  Widget build(BuildContext context) {
    final bookName = getBookName(_currentBookId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bible'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${getBookName(_currentBookId)} Pas. $_currentChapter',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Versi: $_currentVersion',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final selectedBookId = await showSearch<String>(
                context: context,
                delegate: BibleSearchDelegate(),
              );
              if (selectedBookId != null) {
                setState(() {
                  _currentBookId = selectedBookId;
                  _currentChapter = 1;
                  _versesFuture = _fetchVerses();
                });
              }
            },
          ),
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
                    padding: const EdgeInsets.all(12.0),
                    itemCount: verses.length,
                    itemBuilder: (context, index) => Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${verses[index].verseNumber} ',
                                style: TextStyle(
                                  fontSize: _fontSize - 2,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              TextSpan(
                                text: verses[index].text,
                                style: TextStyle(
                                  fontSize: _fontSize,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildChapterNavigation() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                'Pasal $_currentChapter',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: _currentChapter < getMaxChapters(_currentBookId)
                  ? () => setState(() {
                        _currentChapter++;
                        _versesFuture = _fetchVerses();
                      })
                  : null,
            ),
          ],
        ),
      );

  void _showChapterSelector() => showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              Text('Pilih Pasal - ${getBookName(_currentBookId)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1,
                  ),
                  itemCount: getMaxChapters(_currentBookId),
                  itemBuilder: (context, index) {
                    final chapter = index + 1;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentChapter = chapter;
                          _versesFuture = _fetchVerses();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _currentChapter == chapter
                              ? Colors.blue
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '$chapter',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _currentChapter == chapter
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
}

class BibleSearchDelegate extends SearchDelegate<String> {
  final List<String> allBooks =
      bookNameMap.entries.map((e) => e.value).toList();

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = allBooks
        .where((name) => name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final bookName = suggestions[index];
        final bookId =
            bookNameMap.entries.firstWhere((e) => e.value == bookName).key;
        return ListTile(
          title: Text(bookName),
          subtitle: Text(bookId),
          onTap: () {
            close(context, bookId);
          },
        );
      },
    );
  }
}
