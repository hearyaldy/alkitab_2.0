// lib/screens/bookmarks/bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/devotional_model.dart';
import '../../services/devotional_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/sync_queue_processor.dart';
import '../../providers/sync_providers.dart';

// Import existing widgets
import '../../widgets/devotional_bookmarks_list.dart'
    show DevotionalBookmarksList;
import '../../widgets/bible_bookmarks_list.dart' show BibleBookmarksList;
import '../../widgets/notes_bookmarks_list.dart' show NotesBookmarksList;

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<DevotionalModel>> _devotionalsFuture;
  late Future<List<Map<String, dynamic>>> _notesFuture;

  final DevotionalService _devotionalService = DevotionalService();
  late final BookmarkService _bookmarkService;
  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bookmarkService = BookmarkService(SyncQueueProcessor());
    _devotionalsFuture = _devotionalService.getAllDevotionals();
    _notesFuture = fetchNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks() async {
    try {
      final bookmarks = await _bookmarkService.getUserBookmarks();
      return bookmarks.map((bookmark) => bookmark.toJson()).toList();
    } catch (e) {
      debugPrint("Error fetching bookmarks: $e, falling back to local");
      return await _getLocalBookmarks();
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotes() async {
    try {
      final bookmarks = await _bookmarkService.getUserBookmarks(type: 'note');
      return bookmarks.map((bookmark) => bookmark.toJson()).toList();
    } catch (e) {
      debugPrint("Error fetching notes: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chapterBookmarks = prefs.getStringList('bible_chapter_bookmarks') ?? [];
      final verseBookmarks = prefs.getStringList('bible_verse_bookmarks') ?? [];

      List<Map<String, dynamic>> bookmarks = [];

      // Add chapter bookmarks
      for (String bookmark in chapterBookmarks) {
        final parts = bookmark.split('_');
        if (parts.length >= 2) {
          bookmarks.add({
            'id': bookmark,
            'type': 'bible',
            'bookmark_type': 'bible_chapter',
            'book_id': parts[0],
            'chapter_id': int.tryParse(parts[1]) ?? 1,
            'verse_id': null,
            'verse_reference': '${parts[0]} ${parts[1]}',
            'title': 'Bible - ${parts[0]} ${parts[1]}',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Add verse bookmarks
      for (String bookmark in verseBookmarks) {
        final parts = bookmark.split('_');
        if (parts.length >= 3) {
          bookmarks.add({
            'id': bookmark,
            'type': 'bible',
            'bookmark_type': 'bible_verse',
            'book_id': parts[0],
            'chapter_id': int.tryParse(parts[1]) ?? 1,
            'verse_id': int.tryParse(parts[2]) ?? 1,
            'verse_reference': '${parts[0]} ${parts[1]}:${parts[2]}',
            'title': 'Bible - ${parts[0]} ${parts[1]}:${parts[2]}',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      return bookmarks;
    } catch (e) {
      debugPrint("Error getting local bookmarks: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch sync status
    final syncStatus = ref.watch(syncQueueStatusProvider);

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
            // Sync Status Indicator
            syncStatus.when(
              data: (items) => items.isNotEmpty
                  ? Container(
                      color: Colors.yellow[100],
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.sync, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text('${items.length} items pending sync'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => Container(
                color: Colors.red[100],
                padding: const EdgeInsets.all(8),
                child: Text('Sync Error: $error'),
              ),
            ),

            // Existing body content remains the same
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/header_image.png',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.5)),
                  const Positioned(
                    left: 16,
                    bottom: 16,
                    child: Text(
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

            // Existing tab bar and content
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
                  Tab(
                    text: 'Notes',
                    icon: Icon(Icons.note),
                  ),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
            ),

            // Existing tab content remains the same
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Devotionals Tab
                  FutureBuilder<List<DevotionalModel>>(
                    future: _devotionalsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final devotionals = snapshot.data ?? [];

                      // Create the widget explicitly with its constructor
                      return DevotionalBookmarksList(
                        devotionals: devotionals,
                        devotionalService: _devotionalService,
                        onRefresh: () {
                          setState(() {
                            _devotionalsFuture =
                                _devotionalService.refreshCache().then((_) {
                              return _devotionalService.getAllDevotionals();
                            });
                          });
                        },
                      );
                    },
                  ),

                  // Bible Verses Tab
                  BibleBookmarksList(
                    onRefresh: () {
                      setState(() {
                      });
                    },
                  ),

                  // Notes Tab
                  FutureBuilder<List<DevotionalModel>>(
                    future: _devotionalsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final devotionals = snapshot.data ?? [];

                      // Create the widget explicitly with its constructor
                      return NotesBookmarksList(
                        notesFuture: _notesFuture,
                        devotionals: devotionals,
                        onRefresh: () {
                          setState(() {
                            _notesFuture = fetchNotes();
                            _devotionalsFuture =
                                _devotionalService.refreshCache().then((_) {
                              return _devotionalService.getAllDevotionals();
                            });
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
