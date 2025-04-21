// lib/screens/bookmarks/bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoadingDevotionals = false;
  late TabController _tabController;

  Future<void> _loadDevotionals() async {
    setState(() => _isLoadingDevotionals = true);
    try {
      final storage = Supabase.instance.client.storage;
      final files = await storage.from('devotional-readings').list(path: '');

      final List<Map<String, dynamic>> combined = [];
      for (final file in files) {
        if (!file.name.endsWith('.json')) continue;
        final response = await Supabase.instance.client.storage
            .from('devotional-readings')
            .download(file.name);
        final content = String.fromCharCodes(response);
        final parsed = jsonDecode(content);
        if (parsed is List) {
          combined.addAll(parsed.cast<Map<String, dynamic>>());
        }
      }

      if (mounted) {
        setState(() {
          _allDevotionals = combined;
          _isLoadingDevotionals = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load devotionals: $e');
    }
  }

  List<Map<String, dynamic>> _allDevotionals = [];
  late Future<List<Map<String, dynamic>>> _bookmarkFuture;

  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDevotionals();
    _bookmarkFuture = fetchBookmarks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    debugPrint("Current user ID: ${user.id}");

    final response = await Supabase.instance.client
        .from('user_bookmarks')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    debugPrint("Bookmarks response: $response");

    return response.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _deleteBookmark(dynamic bookmarkId) async {
    try {
      debugPrint(
          'Raw bookmark id: $bookmarkId (type: ${bookmarkId.runtimeType})');

      final response = await Supabase.instance.client
          .from('user_bookmarks')
          .delete()
          .eq('id', bookmarkId);

      debugPrint('Delete response: $response');

      setState(() {
        _bookmarkFuture = fetchBookmarks();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bookmark deleted")),
      );
    } catch (e) {
      debugPrint('Delete error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete bookmark: $e")),
      );
    }
  }

  Future<void> _shareBookmark(Map<String, dynamic> bookmark) async {
    try {
      String shareText;

      // Check for type in either 'type' or 'bookmark_type' field
      final bookmarkType = bookmark['type'] ?? bookmark['bookmark_type'];

      if (bookmarkType == 'devotional') {
        // For devotional bookmark
        final devotionalId = bookmark['content_id'];
        final devotionalData =
            devotionalId != null ? _getDevotionalById(devotionalId) : null;

        if (devotionalData != null &&
            devotionalData['title'] != null &&
            devotionalData['content'] != null) {
          final content = devotionalData['content'] as String;
          final excerpt = content.length > 150
              ? '${content.substring(0, 150)}...'
              : content;
          shareText =
              '${devotionalData['title']}\n\n$excerpt\n\nShared from My Faith App';
        } else if (bookmark['title'] != null) {
          // Use bookmark title if available
          shareText = '${bookmark['title']}\n\nShared from My Faith App';
        } else {
          // Fallback
          shareText = 'Devotional bookmark from My Faith App';
        }
      } else {
        // Bible verse
        final reference = bookmark['reference'] ??
            bookmark['verse_reference'] ??
            'Bible verse';
        final verseText = bookmark['verse_text'] ?? '';

        shareText = '$reference - $verseText\n\nShared from My Faith App';
      }

      await Share.share(shareText);
    } catch (e) {
      debugPrint('Share error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share: $e")),
      );
    }
  }

  Map<String, dynamic>? _getDevotionalById(String id) {
    try {
      return _allDevotionals.firstWhere((element) => element['id'] == id);
    } catch (e) {
      return null;
    }
  }

  // Build the devotional bookmarks list
  Widget _buildDevotionalBookmarksList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookmarkFuture,
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
                  onPressed: () {
                    setState(() {
                      _bookmarkFuture = fetchBookmarks();
                    });
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final bookmarks = snapshot.data ?? [];
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

            // Get devotional title and verse reference
            final title = bookmark['title'] ?? 'Untitled Devotional';
            final verseReference = bookmark['verse_reference'] ?? '';

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
                  _showDevotionalBottomSheet(context, bookmark);
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
                                onPressed: () => _shareBookmark(bookmark),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _deleteBookmark(bookmark['id']),
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

  // Show bottom sheet with devotional details
  void _showDevotionalBottomSheet(
      BuildContext context, Map<String, dynamic> bookmark) {
    // Get devotional data if available
    final devotionalId = bookmark['content_id'];
    final devotionalData =
        devotionalId != null ? _getDevotionalById(devotionalId) : null;

    final title =
        bookmark['title'] ?? devotionalData?['title'] ?? 'Untitled Devotional';
    final verseReference = bookmark['verse_reference'] ?? '';
    final content =
        devotionalData?['content'] ?? bookmark['devotional_text'] ?? '';
    final reflectionQuestions = devotionalData?['reflection_questions'] ??
        bookmark['reflection_questions'];
    final prayer = devotionalData?['prayer'] ?? bookmark['prayer'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the bottom sheet expandable
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Initial height (70% of screen)
          minChildSize: 0.5, // Minimum height (50% of screen)
          maxChildSize: 0.95, // Maximum height (95% of screen)
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

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Verse reference if available
                    if (verseReference.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          verseReference,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.indigo.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Divider
                    const Divider(height: 24),

                    // Content
                    if (content.isNotEmpty) ...[
                      const Text(
                        'Devotional',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Reflection Questions
                    if (reflectionQuestions != null &&
                        reflectionQuestions.toString().isNotEmpty) ...[
                      const Text(
                        'Reflection Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reflectionQuestions.toString(),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Prayer
                    if (prayer != null && prayer.toString().isNotEmpty) ...[
                      const Text(
                        'Prayer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        prayer.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          onPressed: () {
                            Navigator.pop(context); // Close the bottom sheet
                            _shareBookmark(bookmark);
                          },
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.menu_book),
                          label: const Text('Go to Devotional'),
                          onPressed: () {
                            Navigator.pop(context); // Close the bottom sheet
                            if (devotionalData != null &&
                                devotionalData['id'] != null) {
                              context.go(
                                  '/devotional/details/${devotionalData['id']}');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Devotional details not available')),
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
      },
    );
  }

  // Build the Bible verse bookmarks list
  Widget _buildBibleBookmarksList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookmarkFuture,
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
                  onPressed: () {
                    setState(() {
                      _bookmarkFuture = fetchBookmarks();
                    });
                  },
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

            // Safe date parsing
            String formattedDate;
            try {
              final date = DateTime.parse(bookmark['created_at'] ?? '');
              formattedDate = '${date.day}/${date.month}/${date.year}';
            } catch (e) {
              formattedDate = 'Date unknown';
            }

            // Get reference from either reference or verse_reference field
            final reference = bookmark['reference'] ??
                bookmark['verse_reference'] ??
                'Unknown Reference';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: InkWell(
                onTap: () {
                  // Show bottom sheet with verse details
                  _showBibleVerseBottomSheet(context, bookmark);
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
                            onPressed: () => _shareBookmark(bookmark),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBookmark(bookmark['id']),
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

  // Show bottom sheet with Bible verse details
  void _showBibleVerseBottomSheet(
      BuildContext context, Map<String, dynamic> bookmark) {
    // Get verse reference and text
    final reference = bookmark['reference'] ??
        bookmark['verse_reference'] ??
        'Unknown Reference';
    final verseText = bookmark['verse_text'] ?? 'Verse text not available';
    final notes = bookmark['notes'];
    final bookId = bookmark['book_id'];
    final chapterId = bookmark['chapter_id'];
    final verseId = bookmark['verse_id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes the bottom sheet expandable
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
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
                            _shareBookmark(bookmark);
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
                                final verse = verseId ?? '1';
                                context.go(
                                    '/bible/read/$bookId/$chapterId/$verse');
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
                                final chapterVerseParts =
                                    chapterVerse.split(':');
                                final chapter = chapterVerseParts[0];
                                final verse = chapterVerseParts.length > 1
                                    ? chapterVerseParts[1]
                                    : '1';

                                // Navigate to the Bible passage
                                context.go('/bible/read/$book/$chapter/$verse');
                              }
                            } catch (e) {
                              // Handle parsing errors
                              debugPrint('Error parsing reference: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Could not navigate to this passage')),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/bible');
              break;
            case 2:
              context.go('/devotional');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Utama'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Alkitab'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: 'Renungan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header image section
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/header_image.png',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withOpacity(0.5)),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: const Text(
                      'My Bookmarks',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/devotional');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar moved below header
            Container(
              color: _themeColor,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    text: 'Devotionals',
                    icon: Icon(Icons.menu_book),
                  ),
                  Tab(
                    text: 'Bible Verses',
                    icon: Icon(Icons.book),
                  ),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Devotionals Tab
                  _buildDevotionalBookmarksList(),

                  // Bible Verses Tab
                  _buildBibleBookmarksList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
