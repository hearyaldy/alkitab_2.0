import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alkitab_2_0/models/highlight_model.dart';
import 'package:alkitab_2_0/providers/highlight_provider.dart';
import 'package:alkitab_2_0/constants/bible_data.dart';

class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(highlightListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sorotan Alkitab')),
      body: highlightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (List<HighlightModel> highlights) {
          if (highlights.isEmpty) {
            return const Center(child: Text('Belum ada ayat yang disorot.'));
          }

          return ListView.builder(
            itemCount: highlights.length,
            itemBuilder: (context, index) {
              final highlight = highlights[index];
              final bookName = getBookName(highlight.bookId);
              final refText = '$bookName ${highlight.chapterId}:${highlight.verseNumber}';

              return ListTile(
                title: Text(highlight.note ?? highlight.verseNumber.toString()),
                subtitle: Text(refText),
                tileColor: Color(int.parse(highlight.colorHex.replaceFirst('#', '0xff'))),
                onTap: () {
                  context.go('/bible-reader?bookId=${highlight.bookId}&chapterId=${highlight.chapterId}&scrollToVerse=${highlight.verseNumber}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
