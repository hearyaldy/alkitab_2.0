import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String? bookId;
  final int chapterId;

  const BibleReaderScreen({
    Key? key,
    this.bookId,
    this.chapterId = 1,
  }) : super(key: key);

  @override
  BibleReaderScreenState createState() => BibleReaderScreenState();
}

class BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  late String _currentBookId;
  late int _currentChapter;
  bool _showSettings = false;
  double _fontSize = 16.0;
  String _currentVersion = 'ABB'; // Default version (Alkitab Berita Baik)

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.bookId ?? 'genesis';
    _currentChapter = widget.chapterId;
  }

  @override
  Widget build(BuildContext context) {
    // This would normally come from a provider or service
    final bookName = _getBookName(_currentBookId);
    final verses = _getSampleVerses();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('$bookName $_currentChapter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.font_download),
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'version') {
                _showVersionDialog();
              } else if (value == 'share') {
                // Share functionality
              } else if (value == 'search') {
                // Search functionality
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'version',
                child: Row(
                  children: [
                    Icon(Icons.translate, size: 20),
                    SizedBox(width: 8),
                    Text('Change Version'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20),
                    SizedBox(width: 8),
                    Text('Search'),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: verses.length,
              itemBuilder: (context, index) {
                return _buildVerseItem(index + 1, verses[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              const Text('Text Size:'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 28.0,
                  divisions: 8,
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                  },
                ),
              ),
              Text(_fontSize.toInt().toString()),
            ],
          ),
          Row(
            children: [
              const Text('Version:'),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _currentVersion,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _currentVersion = newValue;
                    });
                  }
                },
                items: <String>['ABB', 'ATB']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value == 'ABB' ? 'Alkitab Berita Baik' : 'Alkitab Terjemahan Baru'),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterNavigation() {
    return Container(
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
                ? () {
                    setState(() {
                      _currentChapter--;
                    });
                  }
                : null,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _showChapterSelector();
            },
            child: Text(
              'Chapter $_currentChapter',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _currentChapter < _getMaxChapters()
                ? () {
                    setState(() {
                      _currentChapter++;
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVerseItem(int verseNumber, String verseText) {
    return GestureDetector(
      onLongPress: () {
        _showVerseOptions(verseNumber);
      },
      child: Padding(
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
      ),
    );
  }

  void _showChapterSelector() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Chapter - ${_getBookName(_currentBookId)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
              ),
              itemCount: _getMaxChapters(),
              itemBuilder: (context, index) {
                final chapterNumber = index + 1;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentChapter = chapterNumber;
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showVerseOptions(int verseNumber) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('Bookmark'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.highlight),
                title: const Text('Highlight'),
                onTap: () {
                  Navigator.pop(context);
                  _showHighlightOptions(verseNumber);
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Add Note'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHighlightOptions(int verseNumber) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Highlight Verse $verseNumber'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorOption(Colors.yellow[200]!, 'Yellow'),
              _buildColorOption(Colors.green[200]!, 'Green'),
              _buildColorOption(Colors.blue[200]!, 'Blue'),
              _buildColorOption(Colors.red[200]!, 'Red'),
              _buildColorOption(Colors.purple[200]!, 'Purple'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Remove highlight logic
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorOption(Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          // Apply highlight logic
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[400]!),
          ),
        ),
      ),
    );
  }

  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Bible Version'),
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
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  String _getBookName(String bookId) {
    final bookNames = {
      'genesis': 'Genesis',
      'exodus': 'Exodus',
      'matt': 'Matthew',
      'mark': 'Mark',
      'luke': 'Luke',
      'john': 'John',
      // Add more books as needed
    };
    return bookNames[bookId] ?? 'Unknown Book';
  }

  int _getMaxChapters() {
    // In a real app, this would come from your Bible data
    final chapterCounts = {
      'genesis': 50,
      'exodus': 40,
      'matt': 28,
      'mark': 16,
      'luke': 24,
      'john': 21,
      // Add more books as needed
    };
    return chapterCounts[_currentBookId] ?? 1;
  }

  List<String> _getSampleVerses() {
    // This is just sample data for display purposes
    if (_currentBookId == 'matt' && _currentChapter == 5) {
      return [
        "Seeing the crowds, he went up on the mountain, and when he sat down, his disciples came to him.",
        "And he opened his mouth and taught them, saying:",
        "Blessed are the poor in spirit, for theirs is the kingdom of heaven.",
        "Blessed are those who mourn, for they shall be comforted.",
        "Blessed are the meek, for they shall inherit the earth.",
        "Blessed are those who hunger and thirst for righteousness, for they shall be satisfied.",
        "Blessed are the merciful, for they shall receive mercy.",
        "Blessed are the pure in heart, for they shall see God.",
        "Blessed are the peacemakers, for they shall be called sons of God.",
        "Blessed are those who persecuted for righteousness' sake, for theirs is the kingdom of heaven.",
        "Blessed are you when others revile you and persecute you and utter all kinds of evil against you falsely on my account.",
        "Rejoice and be glad, for your reward is great in heaven, for so they persecuted the prophets who were before you.",
        "You are the salt of the earth, but if salt has lost its taste, how shall its saltiness be restored? It is no longer good for anything except to be thrown out and trampled under people's feet.",
        "You are the light of the world. A city set on a hill cannot be hidden.",
        "Nor do people light a lamp and put it under a basket, but on a stand, and it gives light to all in the house.",
      ];
    } else {
      // Return some placeholder verses for other chapters
      return List.generate(
        20,
        (index) => "Sample verse text for ${_getBookName(_currentBookId)} $_currentChapter:${index + 1}",
      );
    }
  }
}