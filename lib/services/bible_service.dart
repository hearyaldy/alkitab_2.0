import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:alkitab_2_0/models/bible_model.dart';

class BibleService {
  static const versionUrls = {
    'ABB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tm.json',
    'ATB':
        'https://cjcokoctuqerrtilrsth.supabase.co/storage/v1/object/public/bible-json/indo_tb.json',
  };

  static Future<List<BibleBook>> fetchBooks(String versionCode) async {
    final url = versionUrls[versionCode];
    if (url == null) throw Exception('Invalid Bible version: $versionCode');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200)
      throw Exception('Failed to load Bible data');

    final data = json.decode(response.body);
    final List<dynamic> verses = data['verses'];

    // Group by book number and name (you can enhance this logic)
    final Map<int, String> bookMap = {};
    for (var v in verses) {
      bookMap[v['book']] = v['book_name'];
    }

    return bookMap.entries.map((e) {
      final bookId = e.value.toLowerCase().replaceAll(' ', '_');
      return BibleBook(
        id: bookId,
        name: e.value,
        abbreviation: bookId.substring(0, 3),
        order: e.key,
        testament: e.key <= 39 ? 'OT' : 'NT',
        chapters: 1, // set to 1 for now (can improve later)
      );
    }).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}
