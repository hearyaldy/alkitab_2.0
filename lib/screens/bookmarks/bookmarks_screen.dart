import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  /// Fetches bookmarks for the current user from "user_bookmarks" table,
  /// ordering by 'id' (since created_at isn't available).
  Future<List<dynamic>> fetchBookmarks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }
    try {
      // Run the query – the result is already a List<dynamic>
      final bookmarks = await Supabase.instance.client
          .from('user_bookmarks')
          .select()
          .eq('user_id', user.id)
          .order('id', ascending: false);
      return bookmarks as List<dynamic>;
    } catch (e) {
      throw Exception("Error fetching bookmarks: $e");
    }
  }

  /// Deletes a bookmark by its id.
  Future<void> _deleteBookmark(dynamic bookmarkId) async {
    try {
      await Supabase.instance.client
          .from('user_bookmarks')
          .delete()
          .eq('id', bookmarkId);
      setState(() {}); // Refresh the UI.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bookmark deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CustomScrollView enables a header with image and back button.
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with a header image and back button.
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(), // Using GoRouter's context.pop()
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text("My Bookmarks"),
              background: Image.asset(
                "assets/images/header_image.png", // Ensure this asset exists.
                fit: BoxFit.cover,
              ),
            ),
          ),
          // The remainder of the page shows the bookmarks list.
          SliverFillRemaining(
            child: FutureBuilder<List<dynamic>>(
              future: fetchBookmarks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text("Error: ${snapshot.error}"),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No bookmarks found."));
                } else {
                  final bookmarks = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {}); // Refresh the UI.
                    },
                    child: ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark =
                            bookmarks[index] as Map<String, dynamic>;
                        return ListTile(
                          title: Text(bookmark['title'] ?? 'No Title'),
                          subtitle: Text(bookmark['verse_reference'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteBookmark(bookmark['id']),
                          ),
                          onTap: () {
                            // Navigate to a detailed view for this bookmark.
                            // For example:
                            // Navigator.pushNamed(context, '/devotionalDetail', arguments: bookmark);
                          },
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
