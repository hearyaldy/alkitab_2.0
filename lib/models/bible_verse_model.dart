// lib/models/bible_verse_model.dart

import 'package:hive/hive.dart';

part 'bible_verse_model.g.dart';

@HiveType(typeId: 10)
class BibleVerseModel extends HiveObject {
  @HiveField(0)
  final String book;

  @HiveField(1)
  final int chapter;

  @HiveField(2)
  final int verse;

  @HiveField(3)
  final String text;

  BibleVerseModel({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory BibleVerseModel.fromJson(Map<String, dynamic> json) {
    return BibleVerseModel(
      book: json['book'] ?? '',
      chapter: json['chapter'] is int
          ? json['chapter']
          : int.tryParse(json['chapter'].toString()) ?? 0,
      verse: json['verse'] is int
          ? json['verse']
          : int.tryParse(json['verse'].toString()) ?? 0,
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }
}
