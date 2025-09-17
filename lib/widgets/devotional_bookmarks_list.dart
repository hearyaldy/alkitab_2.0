// lib/widgets/devotional_bookmarks_list.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/devotional_model.dart';
import '../services/devotional_service.dart';
import 'devotional_detail_sheet.dart';

class DevotionalBookmarksList extends StatefulWidget {
  final List<DevotionalModel> devotionals;
  final DevotionalService devotionalService;
  final VoidCallback onRefresh;

  const DevotionalBookmarksList({
    super.key,
    required this.devotionals,
    required this.devotionalService,
    required this.onRefresh,
  });

  @override
  State<DevotionalBookmarksList> createState() =>
      _DevotionalBookmarksListState();
}

class _DevotionalBookmarksListState extends State<DevotionalBookmarksList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> _deleteBookmark(BuildContext context, String bookmarkId) async {
    try {
      await _firestore.collection('user_bookmarks').doc(bookmarkId).delete();

      widget.onRefresh();

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

  Stream<QuerySnapshot> _getBookmarksStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('user_bookmarks')
          .where('user_id', isEqualTo: user.uid)
          .where('type', isEqualTo: 'devotional')
          .orderBy('created_at', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  Future<void> _shareBookmark(BuildContext context,
      Map<String, dynamic> bookmark, DevotionalModel? devotional) async {
    try {
      String shareText;

      if (devotional != null) {
        final excerpt = devotional.content.length > 150
            ? '${devotional.content.substring(0, 150)}...'
            : devotional.content;
        shareText =
            '${devotional.title}\n\n$excerpt\n\nShared from My Faith App';
      } else if (bookmark['title'] != null) {
        // Use bookmark title if available
        shareText = '${bookmark['title']}\n\nShared from My Faith App';
      } else {
        // Fallback
        shareText = 'Devotional bookmark from My Faith App';
      }

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

  // Helper method to find devotional
  DevotionalModel? _findDevotionalById(String? id) {
    if (id == null) return null;
    try {
      return widget.devotionals.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getBookmarksStream(),
      builder: (context, bookmarkSnapshot) {
        if (bookmarkSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (bookmarkSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${bookmarkSnapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onRefresh,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final snapshot = bookmarkSnapshot.data;
        if (snapshot == null) {
          return const Center(child: Text('No data available'));
        }

        final bookmarks = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        }).toList();

        final devotionalBookmarks = bookmarks
            .where((b) =>
                b['type'] == 'devotional' || b['bookmark_type'] == 'devotional')
            .toList();

        if (devotionalBookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No devotional bookmarks yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bookmark your favorite devotionals to see them here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Go to Devotionals'),
                  onPressed: () => context.go('/devotional'),
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
          itemCount: devotionalBookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = devotionalBookmarks[index];

            // Get devotional data if available
            final contentId = bookmark['content_id'];
            final devotional = _findDevotionalById(contentId);

            // Get devotional title and verse reference
            final title =
                devotional?.title ?? bookmark['title'] ?? 'Untitled Devotional';
            final verseReference =
                devotional?.verseReference ?? bookmark['verse_reference'] ?? '';

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
                  // Show bottom sheet with devotional details
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => DevotionalDetailSheet(
                      bookmark: bookmark,
                      devotionalModel: devotional,
                      onShare: () =>
                          _shareBookmark(context, bookmark, devotional),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (verseReference.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      verseReference,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.indigo.shade700,
                                        fontStyle: FontStyle.italic,
                                      ),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share,
                                    color: Colors.indigo),
                                onPressed: () => _shareBookmark(
                                    context, bookmark, devotional),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteBookmark(
                                    context, bookmark['id'].toString()),
                              ),
                            ],
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
