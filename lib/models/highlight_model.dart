// lib/models/highlight_model.dart
import 'package:hive/hive.dart';

part 'highlight_model.g.dart';

@HiveType(typeId: 3)
class HighlightModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String bookId;

  @HiveField(3)
  final int chapterId;

  @HiveField(4)
  final int verseId;

  @HiveField(5)
  final String colorCode;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final bool isSynced;

  @HiveField(8)
  final String? verseText;

  HighlightModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.chapterId,
    required this.verseId,
    required this.colorCode,
    required this.createdAt,
    this.isSynced = false,
    this.verseText,
  });

  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      bookId: json['book_id'] ?? '',
      chapterId: int.tryParse(json['chapter_id']?.toString() ?? '0') ?? 0,
      verseId: int.tryParse(json['verse_id']?.toString() ?? '0') ?? 0,
      colorCode: json['color_code'] ?? '#FFFF00',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isSynced: json['is_synced'] ?? false,
      verseText: json['verse_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'chapter_id': chapterId,
      'verse_id': verseId,
      'color_code': colorCode,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'verse_text': verseText,
    };
  }

  HighlightModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    int? chapterId,
    int? verseId,
    String? colorCode,
    DateTime? createdAt,
    bool? isSynced,
    String? verseText,
  }) {
    return HighlightModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      verseId: verseId ?? this.verseId,
      colorCode: colorCode ?? this.colorCode,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      verseText: verseText ?? this.verseText,
    );
  }

  @override
  String toString() {
    return 'HighlightModel(id: $id, bookId: $bookId, chapterId: $chapterId, verseId: $verseId)';
  }

  String getReferenceString(Map<String, String> bookNameMap) {
    final bookName = bookNameMap[bookId] ?? bookId;
    return '$bookName $chapterId:$verseId';
  }

  // 🆕 Computed getter needed for services
  String get verseReference {
    return '$bookId $chapterId:$verseId';
  }

  // 🆕 Computed getter needed for services
  String? get highlightText => verseText;
}
