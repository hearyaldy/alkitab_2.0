// lib/screens/tabs/bible_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/bible_service.dart';
import '../../models/bible_model.dart'; // Updated to match your models
import '../../utils/offline_manager.dart';

class BibleTab extends ConsumerStatefulWidget {
  const BibleTab({Key? key}) : super(key: key);

  @override
  ConsumerState<BibleTab> createState() => _BibleTabState();
}

class _BibleTabState extends ConsumerState<BibleTab> {
  final _offlineManager = OfflineManager();
  late Future<List<BibleBook>> _futureBooks;

  @override
  void initState() {
    super.initState();
    _futureBooks = BibleService.fetchBooks('ABB'); // Default version ABB
  }

  void _onBookTap(BuildContext context, BibleBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BibleChapterScreen(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200.0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Alkitab'),
              background: Image.asset(
                'assets/images/header_image.png', // Update this path accordingly
                fit: BoxFit.cover,
              ),
            ),
          ),
          FutureBuilder<List<BibleBook>>(
            future: _futureBooks,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Failed to load Bible books.')),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No books available.')),
                );
              }

              final books = snapshot.data!;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = books[index];
                    return ListTile(
                      title: Text(book.name),
                      onTap: () => _onBookTap(context, book),
                    );
                  },
                  childCount: books.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Separate screen to display the verses of selected book
class BibleChapterScreen extends StatelessWidget {
  final BibleBook book;

  const BibleChapterScreen({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For simplicity, assume chapter 1 first
    return Scaffold(
      appBar: AppBar(
        title: Text(book.name),
      ),
      body: FutureBuilder<List<BibleVerse>>(
        future: BibleService.fetchVerses(
          bookId: book.id,
          chapterId: 1, // Start from chapter 1
          version: 'ABB',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load verses.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No verses available.'));
          }

          final verses = snapshot.data!;
          return ListView.builder(
            itemCount: verses.length,
            itemBuilder: (context, index) {
              final verse = verses[index];
              return ListTile(
                title: Text('${verse.chapterId}:${verse.verseNumber}'),
                subtitle: Text(verse.text),
              );
            },
          );
        },
      ),
    );
  }
}
