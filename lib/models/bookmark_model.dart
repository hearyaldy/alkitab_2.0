// lib/screens/bookmarks/models/bookmark_model.dart

class BookmarkModel {
  final String id;
  final String userId;
  final String? title;
  final String? verseReference;
  final String? verseText;
  final String? bookmarkType;
  final String? type;
  final String? bookId;
  final int? chapterId;
  final int? verseId;
  final String? notes;
  final String? contentId;
  final DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.userId,
    this.title,
    this.verseReference,
    this.verseText,
    this.bookmarkType,
    this.type,
    this.bookId,
    this.chapterId,
    this.verseId,
    this.notes,
    this.contentId,
    required this.createdAt,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'].toString(),
      userId: json['user_id'],
      title: json['title'],
      verseReference: json['verse_reference'] ?? json['reference'],
      verseText: json['verse_text'],
      bookmarkType: json['bookmark_type'],
      type: json['type'],
      bookId: json['book_id'],
      chapterId: json['chapter_id'] != null
          ? int.tryParse(json['chapter_id'].toString())
          : null,
      verseId: json['verse_id'] != null
          ? int.tryParse(json['verse_id'].toString())
          : null,
      notes: json['notes'],
      contentId: json['content_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'verse_reference': verseReference,
      'verse_text': verseText,
      'bookmark_type': bookmarkType,
      'type': type,
      'book_id': bookId,
      'chapter_id': chapterId,
      'verse_id': verseId,
      'notes': notes,
      'content_id': contentId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get bookmarkTypeDisplay {
    return type?.toLowerCase() == 'bible' ||
            bookmarkType?.toLowerCase() == 'bible'
        ? 'Bible'
        : 'Devotional';
  }

  bool get isBibleBookmark {
    return type?.toLowerCase() == 'bible' ||
        bookmarkType?.toLowerCase() == 'bible';
  }

  bool get isDevotionalBookmark {
    return type?.toLowerCase() == 'devotional' ||
        bookmarkType?.toLowerCase() == 'devotional';
  }

  String get formattedDate {
    try {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } catch (e) {
      return 'Date unknown';
    }
  }
}
