// lib/models/note_model.dart
import 'package:hive/hive.dart';

part 'note_model.g.dart'; // Will be generated with build_runner

@HiveType(typeId: 4)
class NoteModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String? bookId;

  @HiveField(3)
  final int? chapterId;

  @HiveField(4)
  final int? verseId;

  @HiveField(5)
  final String content;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime lastModified;

  @HiveField(8)
  final bool isSynced;

  @HiveField(9)
  final String? devotionalId;

  @HiveField(10)
  final String noteType; // "bible", "devotional", or "general"

  @HiveField(11)
  final String? title;

  NoteModel({
    required this.id,
    required this.userId,
    this.bookId,
    this.chapterId,
    this.verseId,
    required this.content,
    required this.createdAt,
    required this.lastModified,
    this.isSynced = false,
    this.devotionalId,
    required this.noteType,
    this.title,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      bookId: json['book_id'],
      chapterId: json['chapter_id'] != null
          ? int.tryParse(json['chapter_id'].toString())
          : null,
      verseId: json['verse_id'] != null
          ? int.tryParse(json['verse_id'].toString())
          : null,
      content: json['content'] ?? json['note_text'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      lastModified: json['last_modified'] != null
          ? DateTime.parse(json['last_modified'])
          : DateTime.now(),
      isSynced: json['is_synced'] ?? false,
      devotionalId: json['devotional_id'],
      noteType: json['note_type'] ?? 'general',
      title: json['title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'verse_id': verseId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'last_modified': lastModified.toIso8601String(),
      'is_synced': isSynced,
      'devotional_id': devotionalId,
      'note_type': noteType,
      'title': title,
    };
  }

  // Create a copy with updated fields
  NoteModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    int? chapterId,
    int? verseId,
    String? content,
    DateTime? createdAt,
    DateTime? lastModified,
    bool? isSynced,
    String? devotionalId,
    String? noteType,
    String? title,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      verseId: verseId ?? this.verseId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      isSynced: isSynced ?? this.isSynced,
      devotionalId: devotionalId ?? this.devotionalId,
      noteType: noteType ?? this.noteType,
      title: title ?? this.title,
    );
  }

  @override
  String toString() {
    if (noteType == 'bible') {
      return 'Note: $bookId $chapterId:$verseId';
    } else if (noteType == 'devotional') {
      return 'Devotional Note: ${title ?? 'Untitled'}';
    } else {
      return 'Note: ${title ?? 'Untitled'}';
    }
  }

  // Get a formatted reference for display
  String getReference(Map<String, String> bookNameMap) {
    if (noteType == 'bible' && bookId != null && chapterId != null) {
      final bookName = bookNameMap[bookId] ?? bookId;
      if (verseId != null) {
        return '$bookName $chapterId:$verseId';
      } else {
        return '$bookName $chapterId';
      }
    } else if (noteType == 'devotional') {
      return title ?? 'Devotional Note';
    } else {
      return title ?? 'Note';
    }
  }
}
