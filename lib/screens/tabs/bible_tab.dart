import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BibleTab extends StatelessWidget {
  const BibleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.indigo;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: themeColor.shade50,
            child: const TabBar(
              tabs: [
                Tab(text: 'Perjanjian Lama'),
                Tab(text: 'Perjanjian Baru'),
              ],
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBookList(context, _oldTestamentBooks),
                _buildBookList(context, _newTestamentBooks),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList(BuildContext context, List<Map<String, String>> books) {
    return ListView.separated(
      itemCount: books.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => const Divider(height: 0),
      itemBuilder: (context, index) {
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
    );
  }

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
}
