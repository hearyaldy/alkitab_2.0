// lib/screens/highlights/highlights_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/services/highlight_service.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';

class HighlightsScreen extends ConsumerStatefulWidget {
  const HighlightsScreen({super.key});

  @override
  HighlightsScreenState createState() => HighlightsScreenState();
}

class HighlightsScreenState extends ConsumerState<HighlightsScreen> {
  late Future<List<BibleHighlight>> _highlightsFuture;

  @override
  void initState() {
    super.initState();
    _highlightsFuture = HighlightService.getAllHighlights();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Highlights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Highlights',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Syncing highlights...')),
              );

              await HighlightService.syncAllHighlights();

              setState(() {
                _highlightsFuture = HighlightService.getAllHighlights();
              });

              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                const SnackBar(content: Text('Highlights synced')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<BibleHighlight>>(
        future: _highlightsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _highlightsFuture = HighlightService.getAllHighlights();
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final highlights = snapshot.data ?? [];

          if (highlights.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.brush_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No highlights yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Long press on a verse to add highlights',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Group highlights by book and chapter
          final groupedHighlights = <String, List<BibleHighlight>>{};

          for (final highlight in highlights) {
            final key = '${highlight.bookId}_${highlight.chapterId}';
            groupedHighlights.putIfAbsent(key, () => []).add(highlight);
          }

          return ListView.builder(
            itemCount: groupedHighlights.length,
            itemBuilder: (context, index) {
              final entry = groupedHighlights.entries.elementAt(index);
              final parts = entry.key.split('_');
              final bookId = parts[0];
              final chapterId = int.parse(parts[1]);
              final highlightsList = entry.value;

              // Sort highlights by verse number
              highlightsList
                  .sort((a, b) => a.verseNumber.compareTo(b.verseNumber));

              final bookName = getBookName(bookId);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text('$bookName $chapterId'),
                  subtitle: Text('${highlightsList.length} highlights'),
                  leading: const Icon(Icons.book),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: highlightsList.length,
                      itemBuilder: (context, i) {
                        final highlight = highlightsList[i];
                        return ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(
                                  int.parse(highlight.colorHex, radix: 16)),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${highlight.verseNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text('Verse ${highlight.verseNumber}'),
                          subtitle: highlight.note != null
                              ? Text(highlight.note!)
                              : const Text('No note'),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: const [
                                    Icon(Icons.visibility, size: 20),
                                    SizedBox(width: 8),
                                    Text('View in Bible'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: const [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit Note'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'color',
                                child: Row(
                                  children: const [
                                    Icon(Icons.color_lens, size: 20),
                                    SizedBox(width: 8),
                                    Text('Change Color'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: const [
                                    Icon(Icons.delete,
                                        size: 20, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Remove Highlight',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'view') {
                                context.go(
                                    '/bible/$bookId/$chapterId?verse=${highlight.verseNumber}');
                              } else if (value == 'edit') {
                                _showEditNoteDialog(highlight);
                              } else if (value == 'color') {
                                _showColorPickerDialog(highlight);
                              } else if (value == 'delete') {
                                _confirmDeleteHighlight(highlight);
                              }
                            },
                          ),
                          onTap: () {
                            context.go(
                                '/bible/$bookId/$chapterId?verse=${highlight.verseNumber}');
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Show dialog to edit highlight note
  void _showEditNoteDialog(BibleHighlight highlight) {
    final TextEditingController controller =
        TextEditingController(text: highlight.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Add a note to this highlight...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newNote = controller.text.trim();

              await HighlightService.addHighlight(
                bookId: highlight.bookId,
                chapterId: highlight.chapterId,
                verseNumber: highlight.verseNumber,
                colorHex: highlight.colorHex,
                note: newNote.isEmpty ? null : newNote,
              );

              Navigator.pop(context);

              setState(() {
                _highlightsFuture = HighlightService.getAllHighlights();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Show color picker dialog
  void _showColorPickerDialog(BibleHighlight highlight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: HighlightColors.all().map((colorHex) {
            final color = Color(int.parse(colorHex, radix: 16));
            final isSelected = highlight.colorHex == colorHex;

            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);

                await HighlightService.addHighlight(
                  bookId: highlight.bookId,
                  chapterId: highlight.chapterId,
                  verseNumber: highlight.verseNumber,
                  colorHex: colorHex,
                  note: highlight.note,
                );

                setState(() {
                  _highlightsFuture = HighlightService.getAllHighlights();
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Highlight color updated')),
                );
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

  // Confirm before deleting highlight
  void _confirmDeleteHighlight(BibleHighlight highlight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Highlight'),
        content: const Text('Are you sure you want to remove this highlight?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await HighlightService.removeHighlight(
                highlight.bookId,
                highlight.chapterId,
                highlight.verseNumber,
              );

              setState(() {
                _highlightsFuture = HighlightService.getAllHighlights();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Highlight removed')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
