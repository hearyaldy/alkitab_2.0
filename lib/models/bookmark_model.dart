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
  final DateTime? createdAt;
  final String? devotionalText;
  final Map<String, dynamic>? reflectionQuestions;
  final String? prayer;

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
    this.createdAt,
    this.devotionalText,
    this.reflectionQuestions,
    this.prayer,
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
      createdAt: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : null,
      devotionalText: json['devotional_text'],
      reflectionQuestions: json['reflection_questions'],
      prayer: json['prayer'],
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
      'date_created': createdAt?.toIso8601String(),
      'devotional_text': devotionalText,
      'reflection_questions': reflectionQuestions,
      'prayer': prayer,
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
      return createdAt != null
          ? '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}'
          : 'Date unknown';
    } catch (e) {
      return 'Date unknown';
    }
  }
}
