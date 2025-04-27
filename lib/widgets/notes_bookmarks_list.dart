// lib/widgets/notes_bookmarks_list.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/devotional_model.dart';

class NotesBookmarksList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> notesFuture;
  final List<DevotionalModel> devotionals;
  final VoidCallback onRefresh;

  const NotesBookmarksList({
    super.key,
    required this.notesFuture,
    required this.devotionals,
    required this.onRefresh,
  });

  DevotionalModel? _findDevotionalById(String? id) {
    if (id == null) return null;
    try {
      return devotionals.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: notesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRefresh,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final notes = snapshot.data ?? [];

        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No notes yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add notes to devotionals to see them here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Go to Devotionals'),
                  onPressed: () => context.go('/devotional'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final devotionalId = note['devotional_id'];
            final content = note['content'] ?? '';

            // Get update date
            DateTime? updatedAt;
            try {
              updatedAt = DateTime.parse(
                  note['updated_at'] ?? DateTime.now().toIso8601String());
            } catch (_) {
              updatedAt = DateTime.now();
            }

            // Find associated devotional if available
            final devotional = _findDevotionalById(devotionalId);
            final title = devotional?.title ?? 'Untitled Devotional';
            final verseRef = devotional?.verseReference ?? '';

            final formattedDate =
                '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: InkWell(
                onTap: () {
                  if (devotional != null) {
                    // Navigate to the devotional
                    // You'll need to create this route or modify to match your app's navigation
                    context.go('/devotional/details/${devotional.id}');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (verseRef.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      verseRef,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.indigo.shade700,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Updated on $formattedDate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
