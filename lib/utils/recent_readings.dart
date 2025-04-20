import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentReading {
  final String bookId;
  final String book;
  final int chapter;
  final double chapterProgress; // 0.0 to 1.0
  final double bookProgress; // 0.0 to 1.0

  RecentReading({
    required this.bookId,
    required this.book,
    required this.chapter,
    required this.chapterProgress,
    required this.bookProgress,
  });

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'book': book,
        'chapter': chapter,
        'chapterProgress': chapterProgress,
        'bookProgress': bookProgress,
      };

  factory RecentReading.fromJson(Map<String, dynamic> json) => RecentReading(
        bookId: json['bookId'],
        book: json['book'],
        chapter: json['chapter'],
        chapterProgress: json['chapterProgress'],
        bookProgress: json['bookProgress'],
      );
}

Future<void> addRecentReading(RecentReading reading) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('recent_readings') ?? [];

  final newEntry = jsonEncode(reading.toJson());
  final updated = [
    newEntry,
    ...raw.where((e) {
      final data = jsonDecode(e);
      return data['bookId'] != reading.bookId ||
          data['chapter'] != reading.chapter;
    })
  ];

  if (updated.length > 5) updated.removeLast();

  await prefs.setStringList('recent_readings', updated);
}
