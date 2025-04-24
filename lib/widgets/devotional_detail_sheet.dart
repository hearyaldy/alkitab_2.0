// lib/widgets/devotional_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/devotional_model.dart';

class DevotionalDetailSheet extends StatelessWidget {
  final Map<String, dynamic> bookmark;
  final DevotionalModel? devotionalModel;
  final VoidCallback onShare;

  const DevotionalDetailSheet({
    super.key,
    required this.bookmark,
    this.devotionalModel,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final title = devotionalModel?.title ?? bookmark['title'] ?? 'Untitled Devotional';
    final verseReference = devotionalModel?.verseReference ?? bookmark['verse_reference'] ?? '';
    final content = devotionalModel?.content ?? bookmark['devotional_text'] ?? bookmark['notes'] ?? '';
    final reflectionQuestions = devotionalModel?.reflectionQuestions ?? [];
    final prayer = devotionalModel?.prayer ?? bookmark['prayer'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.7, // Initial height (70% of screen)
      minChildSize: 0.5, // Minimum height (50% of screen)
      maxChildSize: 0.95, // Maximum height (95% of screen)
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle to drag the sheet
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Verse reference if available
                if (verseReference.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      verseReference,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.indigo.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Divider
                const Divider(height: 24),

                // Content
                if (content.isNotEmpty) ...[
                  const Text(
                    'Devotional',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reflection Questions
                if (reflectionQuestions.isNotEmpty) ...[
                  const Text(
                    'Reflection Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: reflectionQuestions.map((question) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        '• $question',
                        style: const TextStyle(fontSize: 16),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Prayer
                if (prayer.isNotEmpty) ...[
                  const Text(
                    'Prayer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prayer,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        onShare();
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Go to Devotional'),
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                        if (devotionalModel != null) {
                          context.go('/devotional/details/${devotionalModel!.id}');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Devotional details not available')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
                    ),