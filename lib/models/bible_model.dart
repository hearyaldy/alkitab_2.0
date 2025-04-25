import 'package:hive/hive.dart';

part 'bible_model.g.dart'; // We'll generate this with build_runner

@HiveType(typeId: 0)
class BibleBook extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String abbreviation;

  @HiveField(3)
  final int order;

  @HiveField(4)
  final String testament;

  @HiveField(5)
  final int chapters;

  BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.order,
    required this.testament,
    required this.chapters,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      id: json['id'] ?? json['book_name']?.toLowerCase().replaceAll(' ', '_'),
      name: json['name'] ?? json['book_name'],
      abbreviation: json['abbreviation'] ??
          (json['book_name'] as String?)?.substring(0, 3),
      order: json['order'] ?? 0,
      testament: json['testament'] ?? (json['order'] <= 39 ? 'OT' : 'NT'),
      chapters: json['chapters'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'order': order,
      'testament': testament,
      'chapters': chapters,
    };
  }

  @override
  String toString() {
    return 'BibleBook(id: $id, name: $name, chapters: $chapters)';
  }
}

@HiveType(typeId: 1)
class BibleVerse extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final int chapterId;

  @HiveField(3)
  final int verseNumber;

  @HiveField(4)
  final String text;

  BibleVerse({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.verseNumber,
    required this.text,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      id: json['verse'] ?? json['id'] ?? 0,
      bookId: json['book_name']?.toLowerCase().replaceAll(' ', '_') ??
          json['bookId'] ??
          '',
      chapterId: json['chapter'] ?? json['chapterId'] ?? 0,
      verseNumber: json['verse'] ?? json['verseNumber'] ?? 0,
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_id': chapterId,
      'verse_number': verseNumber,
      'text': text,
    };
  }

  @override
  String toString() {
    return 'BibleVerse(bookId: $bookId, chapter: $chapterId, verse: $verseNumber)';
  }
}

@HiveType(typeId: 2)
class BibleVersion extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String code;

  @HiveField(3)
  final String? description;

  BibleVersion({
    required this.id,
    required this.name,
    required this.code,
    this.description,
  });

  factory BibleVersion.fromJson(Map<String, dynamic> json) {
    return BibleVersion(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
    };
  }

  @override
  String toString() {
    return 'BibleVersion(name: $name, code: $code)';
  }
}
