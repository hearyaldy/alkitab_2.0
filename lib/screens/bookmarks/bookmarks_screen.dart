// lib/screens/bookmarks/bookmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/devotional_model.dart';
import '../../services/devotional_service.dart';
import '../../widgets/devotional_bookmarks_list.dart';
import '../../widgets/bible_bookmarks_list.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _bookmarkFuture;
  late Future<List<DevotionalModel>> _devotionalsFuture;

  final DevotionalService _devotionalService = DevotionalService();
  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bookmarkFuture = fetchBookmarks();
    _devotionalsFuture = _devotionalService.getAllDevotionals();
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

            // Tab bar
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
                  FutureBuilder<List<DevotionalModel>>(
                      future: _devotionalsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final devotionals = snapshot.data ?? [];

                        return DevotionalBookmarksList(
                          bookmarkFuture: _bookmarkFuture,
                          devotionals: devotionals,
                          devotionalService: _devotionalService,
                          onRefresh: () {
                            setState(() {
                              _bookmarkFuture = fetchBookmarks();
                              _devotionalsFuture =
                                  _devotionalService.refreshCache().then((_) {
                                return _devotionalService.getAllDevotionals();
                              });
                            });
                          },
                        );
                      }),

                  // Bible Verses Tab
                  BibleBookmarksList(
                    bookmarkFuture: _bookmarkFuture,
                    onRefresh: () {
                      setState(() {
                        _bookmarkFuture = fetchBookmarks();
                      });
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
