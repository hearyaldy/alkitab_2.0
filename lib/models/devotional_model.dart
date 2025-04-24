// lib/models/devotional_model.dart
import 'dart:convert';

class DevotionalModel {
  final String id;
  final String title;
  final String? verseReference;
  final String? verseText;
  final String content;
  final List<String> reflectionQuestions;
  final String prayer;
  final DateTime date;
  final String? author;
  final String? imageUrl;

  DevotionalModel({
    required this.id,
    required this.title,
    this.verseReference,
    this.verseText,
    required this.content,
    required this.reflectionQuestions,
    required this.prayer,
    required this.date,
    this.author,
    this.imageUrl,
  });

  factory DevotionalModel.fromJson(Map<String, dynamic> json) {
    // Handle reflection questions which could be a String, List, or null
    List<String> parseReflectionQuestions(dynamic questions) {
      if (questions == null) return [];

      if (questions is List) {
        return questions.map((q) => q.toString()).toList();
      } else if (questions is String) {
        // Try to parse as JSON list if it's a string
        try {
          final parsed = jsonDecode(questions);
          if (parsed is List) {
            return parsed.map((q) => q.toString()).toList();
          }
        } catch (_) {
          // If can't parse as JSON, treat as a single question
          return [questions];
        }
      }

      return [];
    }

    // Handle date which could be in various formats
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();

      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (_) {
          // If can't parse, return current date
          return DateTime.now();
        }
      }

      return DateTime.now();
    }

    return DevotionalModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Devotional',
      verseReference: json['verse_reference'],
      verseText: json['verse_text'],
      content: json['devotional_text'] ?? json['content'] ?? '',
      reflectionQuestions:
          parseReflectionQuestions(json['reflection_questions']),
      prayer: json['prayer'] ?? '',
      date: parseDate(json['date']),
      author: json['author'],
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'verse_reference': verseReference,
      'verse_text': verseText,
      'content': content,
      'reflection_questions': reflectionQuestions,
      'prayer': prayer,
      'date': date.toIso8601String(),
      'author': author,
      'image_url': imageUrl,
    };
  }
}
