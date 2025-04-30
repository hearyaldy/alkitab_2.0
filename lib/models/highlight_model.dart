// lib/models/highlight_model.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'highlight_model.g.dart';

@HiveType(typeId: 3)
class HighlightModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final int chapterId;

  @HiveField(3)
  final int verseNumber;

  @HiveField(4)
  final String colorHex;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final String? note;

  HighlightModel({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.verseNumber,
    required this.colorHex,
    required this.createdAt,
    this.note,
  });

  // Factory constructor from json
  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id'],
      bookId: json['bookId'],
      chapterId: json['chapterId'],
      verseNumber: json['verseNumber'],
      colorHex: json['colorHex'],
      createdAt: DateTime.parse(json['createdAt']),
      note: json['note'],
    );
  }

  // To json
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterId': chapterId,
      'verseNumber': verseNumber,
      'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  // Get color from hex
  Color get color => Color(int.parse(colorHex, radix: 16));

  // Generate a new highlight with a unique ID
  static HighlightModel create({
    required String bookId,
    required int chapterId,
    required int verseNumber,
    required String colorHex,
    String? note,
  }) {
    return HighlightModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: bookId,
      chapterId: chapterId,
      verseNumber: verseNumber,
      colorHex: colorHex,
      createdAt: DateTime.now(),
      note: note,
    );
  }
}

// Define the available highlight colors
class HighlightColors {
  // Standard highlight colors
  static const yellow = 'FFFFDD77'; // Soft yellow
  static const green = 'FFD1EAC1'; // Soft green
  static const blue = 'FFBDD5F2'; // Soft blue
  static const pink = 'FFF5CAE0'; // Soft pink
  static const purple = 'FFE1D5F2'; // Soft purple
  static const orange = 'FFFFD6AD'; // Soft orange

  // Get all available colors
  static List<String> all() => [yellow, green, blue, pink, purple, orange];

  // Get color from name
  static String fromName(String name) {
    switch (name.toLowerCase()) {
      case 'yellow':
        return yellow;
      case 'green':
        return green;
      case 'blue':
        return blue;
      case 'pink':
        return pink;
      case 'purple':
        return purple;
      case 'orange':
        return orange;
      default:
        return yellow; // Default to yellow
    }
  }

  // Get friendly name from hex
  static String getName(String colorHex) {
    switch (colorHex) {
      case yellow:
        return 'Yellow';
      case green:
        return 'Green';
      case blue:
        return 'Blue';
      case pink:
        return 'Pink';
      case purple:
        return 'Purple';
      case orange:
        return 'Orange';
      default:
        return 'Custom';
    }
  }
}
