// lib/screens/tabs/bible_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/bible_service.dart';
import '../../models/bible_model.dart';

class BibleTab extends ConsumerStatefulWidget {
  const BibleTab({super.key});

  @override
  ConsumerState<BibleTab> createState() => _BibleTabState();
}

class _BibleTabState extends ConsumerState<BibleTab> {
  late Future<List<BibleBook>> _futureBooks;

  final MaterialColor themeColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _futureBooks = BibleService.fetchBooks('ABB');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: FutureBuilder<List<BibleBook>>(
        future: _futureBooks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Failed to load Bible books"));
          }

          final books = snapshot.data!;
          final oldTestament = books.where((b) => b.testament == 'OT').toList();
          final newTestament = books.where((b) => b.testament == 'NT').toList();

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: const Text('Alkitab'),
                  floating: true,
                  pinned: true,
                  snap: true,
                  bottom: TabBar(
                    tabs: const [
                      Tab(text: 'Perjanjian Lama'),
                      Tab(text: 'Perjanjian Baru'),
                    ],
                    labelColor: themeColor,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildBookList(context, oldTestament),
                _buildBookList(context, newTestament),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookList(BuildContext context, List<BibleBook> books) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: PageStorageKey<String>('BookList_${books.first.testament}'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final book = books[index];
                  return ListTile(
                    title: Text(book.name),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      context.go('/bible-reader?bookId=${book.id}&chapterId=1');
                    },
                  );
                },
                childCount: books.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
