import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BibleTab extends StatelessWidget {
  const BibleTab({super.key});

  static final List<Map<String, String>> _oldTestamentBooks = [
    {'id': 'genesis', 'name': 'Kejadian'},
    {'id': 'exodus', 'name': 'Keluaran'},
    {'id': 'leviticus', 'name': 'Imamat'},
    {'id': 'numbers', 'name': 'Bilangan'},
    {'id': 'deuteronomy', 'name': 'Ulangan'},
    {'id': 'joshua', 'name': 'Yosua'},
    {'id': 'judges', 'name': 'Hakim-Hakim'},
    {'id': 'ruth', 'name': 'Rut'},
    {'id': '1_samuel', 'name': '1 Samuel'},
    {'id': '2_samuel', 'name': '2 Samuel'},
    {'id': '1_kings', 'name': '1 Raja-Raja'},
    {'id': '2_kings', 'name': '2 Raja-Raja'},
    {'id': '1_chronicles', 'name': '1 Tawarikh'},
    {'id': '2_chronicles', 'name': '2 Tawarikh'},
    {'id': 'ezra', 'name': 'Ezra'},
    {'id': 'nehemiah', 'name': 'Nehemia'},
    {'id': 'esther', 'name': 'Ester'},
    {'id': 'job', 'name': 'Ayub'},
    {'id': 'psalms', 'name': 'Mazmur'},
    {'id': 'proverbs', 'name': 'Amsal'},
    {'id': 'ecclesiastes', 'name': 'Pengkhotbah'},
    {'id': 'song_of_solomon', 'name': 'Kidung Agung'},
    {'id': 'isaiah', 'name': 'Yesaya'},
    {'id': 'jeremiah', 'name': 'Yeremia'},
    {'id': 'lamentations', 'name': 'Ratapan'},
    {'id': 'ezekiel', 'name': 'Yehezkiel'},
    {'id': 'daniel', 'name': 'Daniel'},
    {'id': 'hosea', 'name': 'Hosea'},
    {'id': 'joel', 'name': 'Yoel'},
    {'id': 'amos', 'name': 'Amos'},
    {'id': 'obadiah', 'name': 'Obaja'},
    {'id': 'jonah', 'name': 'Yunus'},
    {'id': 'micah', 'name': 'Mikha'},
    {'id': 'nahum', 'name': 'Nahum'},
    {'id': 'habakkuk', 'name': 'Habakuk'},
    {'id': 'zephaniah', 'name': 'Zefanya'},
    {'id': 'haggai', 'name': 'Hagai'},
    {'id': 'zechariah', 'name': 'Zakharia'},
    {'id': 'malachi', 'name': 'Maleakhi'},
  ];

  static final List<Map<String, String>> _newTestamentBooks = [
    {'id': 'matt', 'name': 'Matius'},
    {'id': 'mark', 'name': 'Markus'},
    {'id': 'luke', 'name': 'Lukas'},
    {'id': 'john', 'name': 'Yohanes'},
    {'id': 'acts', 'name': 'Kisah Para Rasul'},
    {'id': 'romans', 'name': 'Roma'},
    {'id': '1_corinthians', 'name': '1 Korintus'},
    {'id': '2_corinthians', 'name': '2 Korintus'},
    {'id': 'galatians', 'name': 'Galatia'},
    {'id': 'ephesians', 'name': 'Efesus'},
    {'id': 'philippians', 'name': 'Filipi'},
    {'id': 'colossians', 'name': 'Kolose'},
    {'id': '1_thessalonians', 'name': '1 Tesalonika'},
    {'id': '2_thessalonians', 'name': '2 Tesalonika'},
    {'id': '1_timothy', 'name': '1 Timotius'},
    {'id': '2_timothy', 'name': '2 Timotius'},
    {'id': 'titus', 'name': 'Titus'},
    {'id': 'philemon', 'name': 'Filemon'},
    {'id': 'hebrews', 'name': 'Ibrani'},
    {'id': 'james', 'name': 'Yakobus'},
    {'id': '1_peter', 'name': '1 Petrus'},
    {'id': '2_peter', 'name': '2 Petrus'},
    {'id': '1_john', 'name': '1 Yohanes'},
    {'id': '2_john', 'name': '2 Yohanes'},
    {'id': '3_john', 'name': '3 Yohanes'},
    {'id': 'jude', 'name': 'Yudas'},
    {'id': 'revelation', 'name': 'Wahyu'},
  ];

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color.fromARGB(255, 244, 224, 2);
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Header with the collapsible image
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
            // Pinned TabBar below the header image with a dark background.
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
            // Inject the overlap so that the list starts below the TabBar.
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

// Helper delegate to pin the TabBar below the header image.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color.fromARGB(
          221, 90, 89, 89), // Darker background for the TabBar.
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
