// lib/widgets/bible_verse_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BibleVerseDetailSheet extends StatelessWidget {
  final Map<String, dynamic> bookmark;
  final VoidCallback onShare;

  const BibleVerseDetailSheet({
    super.key,
    required this.bookmark,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Get verse reference and text
    final reference = bookmark['reference'] ??
        bookmark['verse_reference'] ??
        'Unknown Reference';
    final verseText = bookmark['verse_text'] ?? 'Verse text not available';
    final notes = bookmark['notes'];
    final bookId = bookmark['book_id'];
    final chapterId = bookmark['chapter_id'];
    final verseId = bookmark['verse_id'];

    return DraggableScrollableSheet(
      initialChildSize: 0.6, // Initial height (60% of screen)
      minChildSize: 0.5, // Minimum height (50% of screen)
      maxChildSize: 0.9, // Maximum height (90% of screen)
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle to drag the sheet
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                // Reference
                Text(
                  reference,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Verse text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    verseText,
                    style: TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Notes if available
                if (notes != null && notes.toString().isNotEmpty) ...[
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      notes.toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        onShare();
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.book),
                      label: const Text('Go to Passage'),
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        try {
                          if (bookId != null && chapterId != null) {
                            // If we have the book and chapter IDs, use them directly
                            final verse = verseId ?? 1;
                            context.go(
                                '/bible-reader?bookId=$bookId&chapterId=$chapterId&scrollToVerse=$verse');
                          } else {
                            // Otherwise try to parse from the reference
                            final refString = reference.toString();

                            // Extract book name and chapter:verse reference
                            String book;
                            String chapterVerse;

                            // Check if reference contains a space (e.g., "Genesis 1:1")
                            if (refString.contains(' ')) {
                              final parts = refString.split(' ');
                              book = parts[0];
                              chapterVerse =
                                  parts.length > 1 ? parts[1] : '1:1';
                            } else {
                              // Handle case where there's no space (unlikely but safe)
                              book = 'Genesis';
                              chapterVerse = '1:1';
                            }

                            // Split chapter and verse
                            final chapterVerseParts = chapterVerse.split(':');
                            final chapter = chapterVerseParts[0];
                            final verse = chapterVerseParts.length > 1
                                ? chapterVerseParts[1]
                                : '1';

                            // Navigate to the Bible passage
                            context.go(
                                '/bible-reader?bookId=$book&chapterId=$chapter&scrollToVerse=$verse');
                          }
                        } catch (e) {
                          // Handle parsing errors
                          debugPrint('Error parsing reference: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Could not navigate to this passage')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
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
}
