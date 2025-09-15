// lib/widgets/bible_bookmarks_list.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bible_verse_detail_sheet.dart';

class BibleBookmarksList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> bookmarkFuture;
  final VoidCallback onRefresh;

  const BibleBookmarksList({
    super.key,
    required this.bookmarkFuture,
    required this.onRefresh,
  });

  Future<void> _deleteBookmark(BuildContext context, String bookmarkId) async {
    try {
      await Supabase.instance.client
          .from('user_bookmarks')
          .delete()
          .eq('id', bookmarkId);

      onRefresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bookmark deleted")),
        );
      }
    } catch (e) {
      debugPrint('Delete error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete bookmark: $e")),
        );
      }
    }
  }

  Future<void> _shareBookmark(
      BuildContext context, Map<String, dynamic> bookmark) async {
    try {
      // Bible verse
      final reference =
          bookmark['reference'] ?? bookmark['verse_reference'] ?? 'Bible verse';
      final verseText = bookmark['verse_text'] ?? '';

      final shareText = '$reference - $verseText\n\nShared from My Faith App';

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      debugPrint('Share error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to share: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: bookmarkFuture,
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRefresh,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final bookmarks = snapshot.data ?? [];
        final bibleBookmarks = bookmarks
            .where((b) => b['type'] == 'bible' || b['bookmark_type'] == 'bible')
            .toList();

        if (bibleBookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No Bible verse bookmarks yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bookmark your favorite Bible verses to see them here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.book),
                  label: const Text('Go to Bible'),
                  onPressed: () => context.go('/bible'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bibleBookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bibleBookmarks[index];

            // Get reference from either reference or verse_reference field
            final reference = bookmark['reference'] ??
                bookmark['verse_reference'] ??
                'Unknown Reference';

            // Safe date parsing
            String formattedDate;
            try {
              final date = DateTime.parse(bookmark['created_at'] ?? '');
              formattedDate = '${date.day}/${date.month}/${date.year}';
            } catch (e) {
              formattedDate = 'Date unknown';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: InkWell(
                onTap: () {
                  // Show bottom sheet with verse details
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => BibleVerseDetailSheet(
                      bookmark: bookmark,
                      onShare: () => _shareBookmark(context, bookmark),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Bible icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.book,
                          color: Colors.indigo.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Reference and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reference,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bookmarked on $formattedDate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.indigo),
                            onPressed: () => _shareBookmark(context, bookmark),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBookmark(
                                context, bookmark['id'].toString()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
