// lib/screens/tabs/bible_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BibleTab extends ConsumerWidget {
  const BibleTab({super.key});

  static final List<Map<String, String>> _oldTestamentBooks = [
    {'id': 'GEN', 'name': 'Kejadian'},
    {'id': 'EXO', 'name': 'Keluaran'},
    {'id': 'LEV', 'name': 'Imamat'},
    {'id': 'NUM', 'name': 'Bilangan'},
    {'id': 'DEU', 'name': 'Ulangan'},
    {'id': 'JOS', 'name': 'Yosua'},
    {'id': 'JDG', 'name': 'Hakim-Hakim'},
    {'id': 'RUT', 'name': 'Rut'},
    {'id': '1SA', 'name': '1 Samuel'},
    {'id': '2SA', 'name': '2 Samuel'},
    {'id': '1KI', 'name': '1 Raja-Raja'},
    {'id': '2KI', 'name': '2 Raja-Raja'},
    {'id': '1CH', 'name': '1 Tawarikh'},
    {'id': '2CH', 'name': '2 Tawarikh'},
    {'id': 'EZR', 'name': 'Ezra'},
    {'id': 'NEH', 'name': 'Nehemia'},
    {'id': 'EST', 'name': 'Ester'},
    {'id': 'JOB', 'name': 'Ayub'},
    {'id': 'PSA', 'name': 'Mazmur'},
    {'id': 'PRO', 'name': 'Amsal'},
    {'id': 'ECC', 'name': 'Pengkhotbah'},
    {'id': 'SNG', 'name': 'Kidung Agung'},
    {'id': 'ISA', 'name': 'Yesaya'},
    {'id': 'JER', 'name': 'Yeremia'},
    {'id': 'LAM', 'name': 'Ratapan'},
    {'id': 'EZK', 'name': 'Yehezkiel'},
    {'id': 'DAN', 'name': 'Daniel'},
    {'id': 'HOS', 'name': 'Hosea'},
    {'id': 'JOL', 'name': 'Yoel'},
    {'id': 'AMO', 'name': 'Amos'},
    {'id': 'OBA', 'name': 'Obaja'},
    {'id': 'JON', 'name': 'Yunus'},
    {'id': 'MIC', 'name': 'Mikha'},
    {'id': 'NAM', 'name': 'Nahum'},
    {'id': 'HAB', 'name': 'Habakuk'},
    {'id': 'ZEP', 'name': 'Zefanya'},
    {'id': 'HAG', 'name': 'Hagai'},
    {'id': 'ZEC', 'name': 'Zakharia'},
    {'id': 'MAL', 'name': 'Maleakhi'},
  ];

  static final List<Map<String, String>> _newTestamentBooks = [
    {'id': 'MAT', 'name': 'Matius'},
    {'id': 'MRK', 'name': 'Markus'},
    {'id': 'LUK', 'name': 'Lukas'},
    {'id': 'JHN', 'name': 'Yohanes'},
    {'id': 'ACT', 'name': 'Kisah Para Rasul'},
    {'id': 'ROM', 'name': 'Roma'},
    {'id': '1CO', 'name': '1 Korintus'},
    {'id': '2CO', 'name': '2 Korintus'},
    {'id': 'GAL', 'name': 'Galatia'},
    {'id': 'EPH', 'name': 'Efesus'},
    {'id': 'PHP', 'name': 'Filipi'},
    {'id': 'COL', 'name': 'Kolose'},
    {'id': '1TH', 'name': '1 Tesalonika'},
    {'id': '2TH', 'name': '2 Tesalonika'},
    {'id': '1TI', 'name': '1 Timotius'},
    {'id': '2TI', 'name': '2 Timotius'},
    {'id': 'TIT', 'name': 'Titus'},
    {'id': 'PHM', 'name': 'Filemon'},
    {'id': 'HEB', 'name': 'Ibrani'},
    {'id': 'JAS', 'name': 'Yakobus'},
    {'id': '1PE', 'name': '1 Petrus'},
    {'id': '2PE', 'name': '2 Petrus'},
    {'id': '1JN', 'name': '1 Yohanes'},
    {'id': '2JN', 'name': '2 Yohanes'},
    {'id': '3JN', 'name': '3 Yohanes'},
    {'id': 'JUD', 'name': 'Yudas'},
    {'id': 'REV', 'name': 'Wahyu'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = const Color.fromARGB(255, 244, 224, 2);
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                expandedHeight: 160.0,
                pinned: true,
                forceElevated: innerBoxIsScrolled,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/header_image.png',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: const Text(
                          'Alkitab',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  tabs: const [
                    Tab(text: 'Perjanjian Lama'),
                    Tab(text: 'Perjanjian Baru'),
                  ],
                  labelColor: themeColor,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _buildBookList(context, _oldTestamentBooks),
            _buildBookList(context, _newTestamentBooks),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(BuildContext context, List<Map<String, String>> books) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: PageStorageKey<String>('BookList_${books.hashCode}'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final book = books[index];
                  return ListTile(
                    title: Text(book['name']!),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      final bookId = book['id']!;
                      context.go('/bible-reader?bookId=$bookId&chapterId=1');
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color.fromARGB(221, 90, 89, 89),
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
