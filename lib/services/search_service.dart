import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/devotional_model.dart';
import 'devotional_service.dart';

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final DevotionalService _devotionalService = DevotionalService();

  List<DevotionalModel> _allDevotionals = [];
  bool _isInitialized = false;

  // Initialize the search service with all devotionals
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _allDevotionals = await _devotionalService.getAllDevotionals();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing search service: $e');
    }
  }

  // Search devotionals by query
  Future<List<DevotionalModel>> searchDevotionals(String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (query.trim().isEmpty) {
      return _allDevotionals;
    }

    final searchTerms = query.toLowerCase().split(' ');

    return _allDevotionals.where((devotional) {
      return searchTerms.every((term) => _matchesTerm(devotional, term));
    }).toList();
  }

  // Search with filters
  Future<SearchResult> searchWithFilters({
    required String query,
    String? author,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    var results = _allDevotionals;

    // Apply query filter
    if (query.trim().isNotEmpty) {
      final searchTerms = query.toLowerCase().split(' ');
      results = results.where((devotional) {
        return searchTerms.every((term) => _matchesTerm(devotional, term));
      }).toList();
    }

    // Apply author filter
    if (author != null && author.trim().isNotEmpty) {
      results = results.where((devotional) {
        return devotional.author?.toLowerCase().contains(author.toLowerCase()) ?? false;
      }).toList();
    }

    // Apply date range filter
    if (startDate != null || endDate != null) {
      results = results.where((devotional) {
        final date = devotional.date;
        if (startDate != null && date.isBefore(startDate)) return false;
        if (endDate != null && date.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    // Sort results by relevance
    results.sort((a, b) => _calculateRelevance(b, query).compareTo(_calculateRelevance(a, query)));

    return SearchResult(
      devotionals: results,
      totalCount: results.length,
      query: query,
      appliedFilters: {
        if (author != null) 'author': author,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }

  // Get search suggestions
  Future<List<String>> getSearchSuggestions(String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (query.trim().isEmpty) return [];

    final suggestions = <String>{};
    final queryLower = query.toLowerCase();

    for (final devotional in _allDevotionals) {
      // Add title suggestions
      if (devotional.title.toLowerCase().contains(queryLower)) {
        suggestions.add(devotional.title);
      }

      // Add verse reference suggestions
      if (devotional.verseReference != null &&
          devotional.verseReference!.toLowerCase().contains(queryLower)) {
        suggestions.add(devotional.verseReference!);
      }

      // Add author suggestions
      if (devotional.author != null &&
          devotional.author!.toLowerCase().contains(queryLower)) {
        suggestions.add(devotional.author!);
      }
    }

    return suggestions.take(5).toList();
  }

  // Get popular search terms
  Future<List<String>> getPopularSearchTerms() async {
    if (!_isInitialized) {
      await initialize();
    }

    final wordFrequency = <String, int>{};

    for (final devotional in _allDevotionals) {
      final words = [
        ...devotional.title.toLowerCase().split(' '),
        ...devotional.content.toLowerCase().split(' '),
        if (devotional.verseReference != null)
          ...devotional.verseReference!.toLowerCase().split(' '),
      ];

      for (final word in words) {
        final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
        if (cleanWord.length > 3) {
          wordFrequency[cleanWord] = (wordFrequency[cleanWord] ?? 0) + 1;
        }
      }
    }

    final sortedWords = wordFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedWords.take(10).map((e) => e.key).toList();
  }

  // Helper method to check if devotional matches search term
  bool _matchesTerm(DevotionalModel devotional, String term) {
    final fields = [
      devotional.title.toLowerCase(),
      devotional.content.toLowerCase(),
      devotional.verseReference?.toLowerCase() ?? '',
      devotional.verseText?.toLowerCase() ?? '',
      devotional.prayer.toLowerCase(),
      devotional.author?.toLowerCase() ?? '',
      ...devotional.reflectionQuestions.map((q) => q.toLowerCase()),
    ];

    return fields.any((field) => field.contains(term));
  }

  // Calculate relevance score for search results
  double _calculateRelevance(DevotionalModel devotional, String query) {
    if (query.trim().isEmpty) return 0.0;

    double score = 0.0;
    final queryLower = query.toLowerCase();

    // Title match (highest weight)
    if (devotional.title.toLowerCase().contains(queryLower)) {
      score += 10.0;
    }

    // Verse reference match
    if (devotional.verseReference?.toLowerCase().contains(queryLower) ?? false) {
      score += 8.0;
    }

    // Content match
    if (devotional.content.toLowerCase().contains(queryLower)) {
      score += 5.0;
    }

    // Verse text match
    if (devotional.verseText?.toLowerCase().contains(queryLower) ?? false) {
      score += 6.0;
    }

    // Author match
    if (devotional.author?.toLowerCase().contains(queryLower) ?? false) {
      score += 4.0;
    }

    // Reflection questions match
    for (final question in devotional.reflectionQuestions) {
      if (question.toLowerCase().contains(queryLower)) {
        score += 3.0;
      }
    }

    // Prayer match
    if (devotional.prayer.toLowerCase().contains(queryLower)) {
      score += 2.0;
    }

    return score;
  }

  // Refresh devotionals cache
  Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
  }
}

class SearchResult {
  final List<DevotionalModel> devotionals;
  final int totalCount;
  final String query;
  final Map<String, dynamic> appliedFilters;

  SearchResult({
    required this.devotionals,
    required this.totalCount,
    required this.query,
    required this.appliedFilters,
  });
}