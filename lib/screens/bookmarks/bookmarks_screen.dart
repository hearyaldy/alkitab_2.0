import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  /// Fetches bookmarks for the current user from the "user_bookmarks" table.
  Future<List<dynamic>> fetchBookmarks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }
    try {
      final bookmarks = await Supabase.instance.client
          .from('user_bookmarks')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
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
      setState(() {}); // Trigger a refresh
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
      appBar: AppBar(
        title: const Text("My Bookmarks"),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchBookmarks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No bookmarks found."));
          } else {
            final bookmarks = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {}); // Refresh the UI
              },
              child: ListView.builder(
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index] as Map<String, dynamic>;
                  return ListTile(
                    title: Text(bookmark['title'] ?? 'No Title'),
                    subtitle: Text(bookmark['verse_reference'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteBookmark(bookmark['id']),
                    ),
                    onTap: () {
                      // Navigate to a detailed view for this bookmark.
                      // For example, if you have a detail page:
                      // Navigator.pushNamed(context, '/devotionalDetail', arguments: bookmark);
                    },
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}
