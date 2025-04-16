import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late Future<List<Map<String, dynamic>>> _bookmarkFuture;

  final MaterialColor _themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _bookmarkFuture = fetchBookmarks();
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    debugPrint("Current user ID: ${user.id}");

    final response = await Supabase.instance.client
        .from('user_bookmarks')
        .select()
        .eq('user_id', user.id)
        .order('id', ascending: false);

    debugPrint("Bookmarks response: $response");

    return response as List<Map<String, dynamic>>;
  }

  Future<void> _deleteBookmark(int bookmarkId) async {
    await Supabase.instance.client
        .from('user_bookmarks')
        .delete()
        .eq('id', bookmarkId);

    setState(() {
      _bookmarkFuture = fetchBookmarks();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bookmark deleted")),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
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
                                  onPressed: () => _deleteBookmark(b['id']),
                                ),
                                onTap: () {
                                  // Example: context.push('/devotionalDetail', extra: b);
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
