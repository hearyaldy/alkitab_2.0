import 'package:cloud_firestore/cloud_firestore.dart';

class UserPreferences {
  final String userId;
  final String? fontFamily;
  final double? fontSize;
  final String? colorTheme;
  final bool? darkMode;
  final DateTime lastUpdated;

  UserPreferences({
    required this.userId,
    this.fontFamily,
    this.fontSize,
    this.colorTheme,
    this.darkMode,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'colorTheme': colorTheme,
      'darkMode': darkMode,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'],
      fontFamily: json['fontFamily'],
      fontSize: json['fontSize'],
      colorTheme: json['colorTheme'],
      darkMode: json['darkMode'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

class UserBibleMark {
  final String id;
  final String userId;
  final String verseReference;
  final String type; // 'bookmark', 'highlight', 'favorite'
  final String? highlightColor;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserBibleMark({
    required this.id,
    required this.userId,
    required this.verseReference,
    required this.type,
    this.highlightColor,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'verseReference': verseReference,
      'type': type,
      'highlightColor': highlightColor,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserBibleMark.fromJson(Map<String, dynamic> json) {
    return UserBibleMark(
      id: json['id'],
      userId: json['userId'],
      verseReference: json['verseReference'],
      type: json['type'],
      highlightColor: json['highlightColor'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Devotional {
  final String id;
  final String title;
  final String content;
  final String verseReference;
  final DateTime date;
  final DateTime createdAt;

  Devotional({
    required this.id,
    required this.title,
    required this.content,
    required this.verseReference,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'verseReference': verseReference,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Devotional.fromJson(Map<String, dynamic> json) {
    return Devotional(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      verseReference: json['verseReference'],
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
