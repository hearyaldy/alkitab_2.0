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

      if (bookmark['type'] == 'devotional') {
        final devotionalData = _getDevotionalById(bookmark['content_id']);
        if (devotionalData != null) {
          shareText =
              '${devotionalData['title']}\n\n${devotionalData['content'].substring(0, 150)}...\n\nShared from My Faith App';
        } else {
          shareText = 'Bookmark from My Faith App';
        }
      } else {
        // Bible verse
        shareText =
            '${bookmark['reference']} - ${bookmark['verse_text']}\n\nShared from My Faith App';
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
        final devotionalBookmarks =
            bookmarks.where((b) => b['type'] == 'devotional').toList();

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
            final devotionalId = bookmark['content_id'];
            final devotionalData = _getDevotionalById(devotionalId);

            if (devotionalData == null) {
              // Devotional data not found (perhaps deleted or not loaded)
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: const Text('Devotional not found'),
                  subtitle: Text('Bookmark ID: ${bookmark['id']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBookmark(bookmark['id']),
                  ),
                ),
              );
            }

            final date = DateTime.parse(bookmark['created_at']);
            final formattedDate = '${date.day}/${date.month}/${date.year}';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      devotionalData['title'] ?? 'Untitled Devotional',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text('Bookmarked on $formattedDate'),
                    trailing: Row(
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
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      devotionalData['content'] != null
                          ? (devotionalData['content'] as String).length > 150
                              ? '${(devotionalData['content'] as String).substring(0, 150)}...'
                              : devotionalData['content']
                          : 'No content available',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        child: const Text('Read More'),
                        onPressed: () {
                          context.go(
                              '/devotional/details/${devotionalData['id']}');
                        },
                      ),
                    ),
                  ),
                ],
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
        final bibleBookmarks =
            bookmarks.where((b) => b['type'] == 'bible').toList();

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
            final date = DateTime.parse(bookmark['created_at']);
            final formattedDate = '${date.day}/${date.month}/${date.year}';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      bookmark['reference'] ?? 'Unknown Reference',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text('Bookmarked on $formattedDate'),
                    trailing: Row(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.indigo.withOpacity(0.3)),
                      ),
                      child: Text(
                        bookmark['verse_text'] ?? 'Verse text not available',
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        child: const Text('Go to Passage'),
                        onPressed: () {
                          // Parse the reference to get book, chapter, verse
                          final parts =
                              bookmark['reference'].toString().split(' ');
                          final book = parts[0];
                          final chapterVerse = parts.length > 1
                              ? parts[1].split(':')
                              : ['1', '1'];
                          final chapter = chapterVerse[0];
                          final verse =
                              chapterVerse.length > 1 ? chapterVerse[1] : '1';

                          context.go('/bible/read/$book/$chapter/$verse');
                        },
                      ),
                    ),
                  ),
                ],
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
            SizedBox(
              height: 180,
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
                        fontSize: 20,
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
                  // Add tabs at the bottom of the header
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Devotionals'),
                          Tab(text: 'Bible Verses'),
                        ],
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
