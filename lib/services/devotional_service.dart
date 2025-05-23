// lib/services/devotional_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/devotional_model.dart';

class DevotionalService {
  static final DevotionalService _instance = DevotionalService._internal();

  // Singleton pattern
  factory DevotionalService() {
    return _instance;
  }

  DevotionalService._internal();

  // Cache devotionals to avoid frequent reloading
  List<DevotionalModel> _cachedDevotionals = [];
  DateTime? _lastLoaded;

  // Access Supabase safely
  SupabaseClient get _supabase => Supabase.instance.client;

  // Get all devotionals
  Future<List<DevotionalModel>> getAllDevotionals() async {
    if (_cachedDevotionals.isNotEmpty &&
        _lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!).inHours < 1) {
      return _cachedDevotionals;
    }

    try {
      final storage = _supabase.storage;
      final files = await storage.from('devotional-readings').list(path: '');

      final List<DevotionalModel> devotionals = [];

      for (final file in files) {
        if (!file.name.endsWith('.json')) continue;

        final response =
            await storage.from('devotional-readings').download(file.name);
        final content = String.fromCharCodes(response);
        final parsed = jsonDecode(content);

        if (parsed is List) {
          for (var item in parsed) {
            try {
              devotionals.add(DevotionalModel.fromJson(item));
            } catch (e) {
              debugPrint('Error parsing devotional: $e');
            }
          }
        }
      }

      _cachedDevotionals = devotionals;
      _lastLoaded = DateTime.now();

      return devotionals;
    } catch (e) {
      debugPrint('Failed to load devotionals: $e');
      return [];
    }
  }

  // Get a specific devotional by ID
  Future<DevotionalModel?> getDevotionalById(String id) async {
    if (_cachedDevotionals.isNotEmpty) {
      try {
        return _cachedDevotionals.firstWhere((d) => d.id == id);
      } catch (e) {
        // Not found in cache
      }
    }

    final devotionals = await getAllDevotionals();
    try {
      return devotionals.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get today's devotional
  Future<DevotionalModel?> getTodayDevotional() async {
    final devotionals = await getAllDevotionals();
    if (devotionals.isEmpty) return null;

    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final index = dayOfYear % devotionals.length;
    return devotionals[index];
  }

  // Get featured or recent devotionals
  Future<List<DevotionalModel>> getFeaturedDevotionals({int count = 5}) async {
    final devotionals = await getAllDevotionals();
    if (devotionals.isEmpty) return [];

    devotionals.sort((a, b) => b.date.compareTo(a.date));
    return devotionals.take(count).toList();
  }

  // Force refresh the cache
  Future<void> refreshCache() async {
    _cachedDevotionals = [];
    _lastLoaded = null;
    await getAllDevotionals();
  }
}
