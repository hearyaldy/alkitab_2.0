// lib/providers/bible_version_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bibleVersionProvider =
    StateNotifierProvider<BibleVersionNotifier, String>((ref) {
  return BibleVersionNotifier();
});

class BibleVersionNotifier extends StateNotifier<String> {
  BibleVersionNotifier() : super('ABB');

  void setVersion(String version) {
    state = version;
  }
}
