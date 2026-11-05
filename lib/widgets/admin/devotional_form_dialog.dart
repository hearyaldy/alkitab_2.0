// lib/widgets/admin/devotional_form_dialog.dart

import 'package:flutter/material.dart';
import '../../models/devotional_model.dart';

class DevotionalFormDialog extends StatefulWidget {
  final String title;
  final DevotionalModel? initialDevotional;
  final Future<DevotionalModel?> Function(DevotionalModel devotional) onSave;

  const DevotionalFormDialog({
    super.key,
    required this.title,
    this.initialDevotional,
    required this.onSave,
  });

  @override
  State<DevotionalFormDialog> createState() => _DevotionalFormDialogState();
}

class _DevotionalFormDialogState extends State<DevotionalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _verseReferenceController = TextEditingController();
  final _verseTextController = TextEditingController();
  final _contentController = TextEditingController();
  final _prayerController = TextEditingController();
  final _authorController = TextEditingController();
  final _imageUrlController = TextEditingController();

  final List<TextEditingController> _questionControllers = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final devotional = widget.initialDevotional;
    if (devotional != null) {
      _titleController.text = devotional.title;
      _verseReferenceController.text = devotional.verseReference ?? '';
      _verseTextController.text = devotional.verseText ?? '';
      _contentController.text = devotional.content;
      _prayerController.text = devotional.prayer;
      _authorController.text = devotional.author ?? '';
      _imageUrlController.text = devotional.imageUrl ?? '';
      _selectedDate = devotional.date;

      // Initialize reflection questions
      for (int i = 0; i < devotional.reflectionQuestions.length; i++) {
        final controller = TextEditingController(text: devotional.reflectionQuestions[i]);
        _questionControllers.add(controller);
      }
    }

    // Ensure at least one question field
    if (_questionControllers.isEmpty) {
      _questionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _verseReferenceController.dispose();
    _verseTextController.dispose();
    _contentController.dispose();
    _prayerController.dispose();
    _authorController.dispose();
    _imageUrlController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addQuestionField() {
    setState(() {
      _questionControllers.add(TextEditingController());
    });
  }

  void _removeQuestionField(int index) {
    if (_questionControllers.length > 1) {
      setState(() {
        _questionControllers[index].dispose();
        _questionControllers.removeAt(index);
      });
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final reflectionQuestions = _questionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final devotional = DevotionalModel(
        id: widget.initialDevotional?.id ?? '',
        title: _titleController.text.trim(),
        verseReference: _verseReferenceController.text.trim().isEmpty
            ? null
            : _verseReferenceController.text.trim(),
        verseText: _verseTextController.text.trim().isEmpty
            ? null
            : _verseTextController.text.trim(),
        content: _contentController.text.trim(),
        reflectionQuestions: reflectionQuestions,
        prayer: _prayerController.text.trim(),
        date: _selectedDate,
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
      );

      final result = await widget.onSave(devotional);
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving devotional: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(context),
              _buildHeader(context),
              Expanded(child: _buildForm(scrollController)),
              _buildActions(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ScrollController scrollController) {
    return Container(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                // Date
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Verse Reference
                TextFormField(
                  controller: _verseReferenceController,
                  decoration: const InputDecoration(
                    labelText: 'Verse Reference',
                    hintText: 'e.g., John 3:16',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Verse Text
                TextFormField(
                  controller: _verseTextController,
                  decoration: const InputDecoration(
                    labelText: 'Verse Text',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Content
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Devotional Content *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Content is required' : null,
                ),
                const SizedBox(height: 16),

                // Reflection Questions
                const Text(
                  'Reflection Questions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(_questionControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _questionControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Question ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeQuestionField(index),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                  onPressed: _addQuestionField,
                ),
                const SizedBox(height: 16),

                // Prayer
                TextFormField(
                  controller: _prayerController,
                  decoration: const InputDecoration(
                    labelText: 'Prayer *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Prayer is required' : null,
                ),
                const SizedBox(height: 16),

                // Author
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Image URL
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildActions(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 40),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}