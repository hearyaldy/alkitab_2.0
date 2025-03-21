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

class BibleChapter {
  final int id;
  final String bookId;
  final int chapterNumber;
  final List<BibleVerse> verses;
  
  BibleChapter({
    required this.id,
    required this.bookId,
    required this.chapterNumber,
    required this.verses,
  });
  
  factory BibleChapter.fromJson(Map<String, dynamic> json) {
    final List<dynamic> versesJson = json['verses'];
    
    return BibleChapter(
      id: json['id'],
      bookId: json['book_id'],
      chapterNumber: json['chapter_number'],
      verses: versesJson.map((v) => BibleVerse.fromJson(v)).toList(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_number': chapterNumber,
      'verses': verses.map((v) => v.toJson()).toList(),
    };
  }
}

class BibleVerse {
  final int id;
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
      id: json['id'],
      bookId: json['book_id'],
      chapterId: json['chapter_id'],
      verseNumber: json['verse_number'],
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