class BibleBook {
  final String id;
  final String name;
  final String abbreviation;
  final int order;
  final String testament;
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
      id: json['id'],
      name: json['name'],
      abbreviation: json['abbreviation'],
      order: json['order'],
      testament: json['testament'],
      chapters: json['chapters'],
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
}

class BibleVerse {
  final int id; // can be same as verseNumber
  final String bookId;
  final int chapterId;
  final int verseNumber;
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
      id: json['verse'],
      bookId: json['book_name'].toLowerCase().replaceAll(' ', '_'),
      chapterId: json['chapter'],
      verseNumber: json['verse'],
      text: json['text'],
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
}

class BibleVersion {
  final String id;
  final String name;
  final String code;
  final String? description;

  BibleVersion({
    required this.id,
    required this.name,
    required this.code,
    this.description,
  });

  factory BibleVersion.fromJson(Map<String, dynamic> json) {
    return BibleVersion(
      id: json['id'],
      name: json['name'],
      code: json['code'],
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
}
