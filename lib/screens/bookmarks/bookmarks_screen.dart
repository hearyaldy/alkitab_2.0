import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  bool _isLoadingDevotionals = false;
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
      debugPrint('Failed to load devotionals: \$e');
    }
  }

  List<Map<String, dynamic>> _allDevotionals = [];
  late Future<List<Map<String, dynamic>>> _bookmarkFuture;

  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _loadDevotionals();
    _bookmarkFuture = fetchBookmarks();
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    debugPrint("Current user ID: \${user.id}");

    final response = await Supabase.instance.client
        .from('user_bookmarks')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    debugPrint("Bookmarks response: \$response");

    if (response is List) {
      return response.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception("Invalid response format");
    }
  }

  Future<void> _deleteBookmark(dynamic bookmarkId) async {
    try {
      debugPrint(
          'Raw bookmark id: \$bookmarkId (type: \${bookmarkId.runtimeType})');

      final response = await Supabase.instance.client
          .from('user_bookmarks')
          .delete()
          .eq('id', bookmarkId);

      debugPrint('Delete response: \$response');

      setState(() {
        _bookmarkFuture = fetchBookmarks();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bookmark deleted")),
      );
    } catch (e, stack) {
      debugPrint('Delete error: \$e\n\$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete bookmark: \$e")),
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
                    child: Text(
                      'My Bookmarks',
                      style: const TextStyle(
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
                  )
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _bookmarkFuture,
                builder: (context, snapshot) {
                  if (_isLoadingDevotionals ||
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: \${snapshot.error}"));
                  } else if (snapshot.data!.isEmpty) {
                    return const Center(child: Text("No bookmarks found."));
                  } else {
                    final bookmarks = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _bookmarkFuture = fetchBookmarks();
                        });
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: bookmarks.length,
                        itemBuilder: (context, index) {
                          final b = bookmarks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(
                                  b['title'] ?? 'No Title',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _themeColor,
                                  ),
                                ),
                                subtitle: Text(
                                  b['verse_reference'] ?? '',
                                  style: TextStyle(color: _themeColor.shade700),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Delete Bookmark',
                                  onPressed: () async {
                                    final shouldDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Bookmark'),
                                        content: const Text(
                                            'Are you sure you want to delete this bookmark?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (shouldDelete == true) {
                                      _deleteBookmark(b['id']);
                                    }
                                  },
                                ),
                                onTap: () {
                                  final devotional = _allDevotionals.firstWhere(
                                    (dev) =>
                                        dev['verse_reference'] ==
                                        b['verse_reference'],
                                    orElse: () => {},
                                  );

                                  if (devotional.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Devotional content not found.')),
                                    );
                                    return;
                                  }

                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                    ),
                                    builder: (ctx) {
                                      return DraggableScrollableSheet(
                                        expand: false,
                                        builder: (context, scrollController) {
                                          return SingleChildScrollView(
                                            controller: scrollController,
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b['title'] ?? 'Untitled',
                                                  style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  b['verse_reference'] ?? '',
                                                  style: const TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  devotional[
                                                          'devotional_text'] ??
                                                      '',
                                                  style: const TextStyle(
                                                      height: 1.5),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text('Prayer:',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                Text(
                                                  devotional['prayer'] ?? '',
                                                  style: const TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic),
                                                ),
                                                const SizedBox(height: 24),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Close'),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: TextButton.icon(
                                                    onPressed: () {
                                                      final title = b[
                                                              'title'] ??
                                                          'Untitled Devotional';
                                                      final verse =
                                                          b['verse_reference'] ??
                                                              '';
                                                      final text = devotional[
                                                              'devotional_text'] ??
                                                          '';
                                                      final prayer = devotional[
                                                              'prayer'] ??
                                                          '';
                                                      final content =
                                                          '$title\n$verse\n\n$text\n\n🙏 $prayer';
                                                      Share.share(content,
                                                          subject: title);
                                                    },
                                                    icon:
                                                        const Icon(Icons.share),
                                                    label: const Text('Share'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
