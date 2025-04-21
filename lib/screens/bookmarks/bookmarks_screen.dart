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

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
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