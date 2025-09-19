// lib/screens/admin/devotional_admin_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/devotional_model.dart';
import '../../services/devotional_service.dart';
import '../../services/admin_service.dart';
import '../../widgets/admin/devotional_form_dialog.dart';

class DevotionalAdminScreen extends StatefulWidget {
  const DevotionalAdminScreen({super.key});

  @override
  State<DevotionalAdminScreen> createState() => _DevotionalAdminScreenState();
}

class _DevotionalAdminScreenState extends State<DevotionalAdminScreen> {
  final DevotionalService _devotionalService = DevotionalService();
  final AdminService _adminService = AdminService();
  final Uuid _uuid = const Uuid();

  List<DevotionalModel> _devotionals = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadDevotionals();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin;
    setState(() {
      _isAdmin = isAdmin;
    });

    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied. Admin privileges required.')),
        );
        context.go('/');
      }
    }
  }

  Future<void> _loadDevotionals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final devotionals = await _devotionalService.getAllDevotionals();
      devotionals.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _devotionals = devotionals;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading devotionals: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createDevotional() async {
    final result = await showDialog<DevotionalModel>(
      context: context,
      builder: (context) => DevotionalFormDialog(
        title: 'Create New Devotional',
        onSave: (devotional) async {
          final newDevotional = DevotionalModel(
            id: _uuid.v4(),
            title: devotional.title,
            verseReference: devotional.verseReference,
            verseText: devotional.verseText,
            content: devotional.content,
            reflectionQuestions: devotional.reflectionQuestions,
            prayer: devotional.prayer,
            date: devotional.date,
            author: devotional.author,
            imageUrl: devotional.imageUrl,
          );

          final success = await _devotionalService.uploadDevotional(newDevotional);
          if (success) {
            await _devotionalService.refreshCache();
            return newDevotional;
          }
          return null;
        },
      ),
    );

    if (result != null) {
      await _loadDevotionals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devotional created successfully')),
        );
      }
    }
  }

  Future<void> _editDevotional(DevotionalModel devotional) async {
    final result = await showDialog<DevotionalModel>(
      context: context,
      builder: (context) => DevotionalFormDialog(
        title: 'Edit Devotional',
        initialDevotional: devotional,
        onSave: (editedDevotional) async {
          final success = await _devotionalService.uploadDevotional(editedDevotional);
          if (success) {
            await _devotionalService.refreshCache();
            return editedDevotional;
          }
          return null;
        },
      ),
    );

    if (result != null) {
      await _loadDevotionals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devotional updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteDevotional(DevotionalModel devotional) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Devotional'),
        content: Text('Are you sure you want to delete "${devotional.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _devotionalService.deleteDevotional(devotional.id);
      if (success) {
        await _loadDevotionals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Devotional deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete devotional')),
          );
        }
      }
    }
  }

  Future<void> _bulkImportDevotionals() async {
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BulkImportDialog(onFileSelected: _pickJsonFile),
    );

    if (result != null && result.isNotEmpty) {
      await _processJsonImport(result);
    }
  }

  Future<String?> _pickJsonFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;

        // Check file size (limit to 10MB)
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File too large. Maximum size is 10MB.')),
            );
          }
          return null;
        }

        // Read file content
        final bytes = file.bytes;
        if (bytes != null) {
          final content = String.fromCharCodes(bytes);
          return content;
        } else {
          // Fallback for platforms that don't support bytes
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read file. Please try copy-paste method.')),
            );
          }
          return null;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
    return null;
  }

  Future<void> _processJsonImport(String jsonText) async {
    if (jsonText.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide JSON data')),
        );
      }
      return;
    }

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing import...'),
              ],
            ),
          ),
        );
      }

      final dynamic parsedJson = jsonDecode(jsonText);

      if (parsedJson is! List) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JSON must be an array of devotional objects')),
          );
        }
        return;
      }

      int successCount = 0;
      int errorCount = 0;

      // Process each item with a unique date
      final baseDate = DateTime.now();

      for (int index = 0; index < parsedJson.length; index++) {
        try {
          var item = parsedJson[index];
          if (item is! Map<String, dynamic>) {
            errorCount++;
            continue;
          }

          // Ensure required fields and generate ID if missing
          final Map<String, dynamic> devotionalData = Map.from(item);
          if (!devotionalData.containsKey('id') || devotionalData['id'] == null || devotionalData['id'].toString().isEmpty) {
            devotionalData['id'] = _uuid.v4();
          }

          // Set incremental dates if missing (each devotional gets a different date)
          if (!devotionalData.containsKey('date') || devotionalData['date'] == null) {
            devotionalData['date'] = baseDate.add(Duration(days: index)).toIso8601String();
          }

          // Set default author if missing
          if (!devotionalData.containsKey('author') || devotionalData['author'] == null) {
            devotionalData['author'] = 'Admin Import';
          }

          // Ensure required prayer field exists
          if (!devotionalData.containsKey('prayer') || devotionalData['prayer'] == null) {
            devotionalData['prayer'] = 'Tuhan, terima kasih untuk firman-Mu hari ini. Bantulah kami untuk mengaplikasikannya dalam hidup kami. Amin.';
          }

          // Ensure reflection_questions is properly formatted
          if (!devotionalData.containsKey('reflection_questions') || devotionalData['reflection_questions'] == null) {
            devotionalData['reflection_questions'] = <String>[];
          }

          final devotional = DevotionalModel.fromJson(devotionalData);

          final success = await _devotionalService.uploadDevotional(devotional);
          if (success) {
            successCount++;
          } else {
            errorCount++;
          }
        } catch (e) {
          debugPrint('Error processing devotional item at index $index: $e');
          errorCount++;
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (successCount > 0) {
          await _devotionalService.refreshCache();
          await _loadDevotionals();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import completed: $successCount successful, $errorCount errors'),
              backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
            ),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid JSON format: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devotional Admin'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Import JSON',
            onPressed: _bulkImportDevotionals,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevotionals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Total Devotionals', _devotionals.length.toString()),
                      _buildStatItem('This Month', _getThisMonthCount().toString()),
                      if (_adminService.isSuperadmin)
                        _buildStatItem('Superadmin', '✓'),
                    ],
                  ),
                ),

                // Devotionals list
                Expanded(
                  child: _devotionals.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No devotionals found',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _devotionals.length,
                          itemBuilder: (context, index) {
                            final devotional = _devotionals[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.indigo,
                                  child: Text(
                                    devotional.title.isNotEmpty
                                        ? devotional.title[0].toUpperCase()
                                        : 'D',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  devotional.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (devotional.verseReference != null)
                                      Text(
                                        devotional.verseReference!,
                                        style: TextStyle(
                                          color: Colors.indigo.shade700,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    Text(
                                      '${devotional.date.day}/${devotional.date.month}/${devotional.date.year}',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _editDevotional(devotional);
                                        break;
                                      case 'delete':
                                        _deleteDevotional(devotional);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _editDevotional(devotional),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDevotional,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  int _getThisMonthCount() {
    final now = DateTime.now();
    return _devotionals.where((d) =>
        d.date.year == now.year && d.date.month == now.month
    ).length;
  }
}

class _BulkImportDialog extends StatefulWidget {
  final Future<String?> Function() onFileSelected;

  const _BulkImportDialog({required this.onFileSelected});

  @override
  State<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<_BulkImportDialog> {
  final TextEditingController _jsonController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Import Devotionals'),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Import options
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await widget.onFileSelected();
                      if (result != null && mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Choose File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('OR', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Text('Paste JSON below:'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Expected format: Array of devotional objects',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _jsonController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '[\n  {\n    "title": "Devotional Title",\n    "content": "...",\n    ...\n  }\n]',
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_jsonController.text.trim().isNotEmpty) {
              Navigator.pop(context, _jsonController.text);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Import'),
        ),
      ],
    );
  }
}