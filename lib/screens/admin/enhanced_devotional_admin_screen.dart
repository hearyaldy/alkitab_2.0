import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/devotional_model.dart';
import '../../services/devotional_service.dart';
import '../../services/admin_service.dart';
import '../../services/lazy_loading_service.dart';
import '../../widgets/admin/devotional_form_dialog.dart';

class EnhancedDevotionalAdminScreen extends StatefulWidget {
  const EnhancedDevotionalAdminScreen({super.key});

  @override
  State<EnhancedDevotionalAdminScreen> createState() => _EnhancedDevotionalAdminScreenState();
}

class _EnhancedDevotionalAdminScreenState extends State<EnhancedDevotionalAdminScreen> {
  final DevotionalService _devotionalService = DevotionalService();
  final AdminService _adminService = AdminService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();

  List<DevotionalModel> _devotionals = [];
  List<DevotionalModel> _filteredDevotionals = [];
  LazyListController<DevotionalModel>? _lazyController;
  Set<String> _selectedDevotionals = {};
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isSelectionMode = false;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadDevotionals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lazyController?.dispose();
    super.dispose();
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
    if (!_isAdmin) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final devotionals = await _devotionalService.getAllDevotionals();
      setState(() {
        _devotionals = devotionals;
        _filteredDevotionals = devotionals;
        _isLoading = false;

        // Create lazy loading controller for large datasets
        if (devotionals.length > 50) {
          _lazyController?.dispose();
          _lazyController = LazyListController<DevotionalModel>(
            fullList: devotionals,
            pageSize: 30,
            threshold: 10,
          );
        } else {
          _lazyController?.dispose();
          _lazyController = null;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading devotionals: $e')),
        );
      }
    }
  }

  void _filterDevotionals(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDevotionals = _devotionals;
      } else {
        _filteredDevotionals = _devotionals.where((devotional) {
          return devotional.title.toLowerCase().contains(query.toLowerCase()) ||
                 devotional.content.toLowerCase().contains(query.toLowerCase()) ||
                 (devotional.verseReference?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
                 (devotional.author?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }

      // Update lazy controller with filtered results
      if (_filteredDevotionals.length > 50) {
        _lazyController?.dispose();
        _lazyController = LazyListController<DevotionalModel>(
          fullList: _filteredDevotionals,
          pageSize: 30,
          threshold: 10,
        );
      } else {
        _lazyController?.dispose();
        _lazyController = null;
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDevotionals.clear();
        _selectAll = false;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedDevotionals = _filteredDevotionals.map((d) => d.id ?? d.title).toSet();
      } else {
        _selectedDevotionals.clear();
      }
    });
  }

  void _toggleDevotionalSelection(String id) {
    setState(() {
      if (_selectedDevotionals.contains(id)) {
        _selectedDevotionals.remove(id);
      } else {
        _selectedDevotionals.add(id);
      }
      _selectAll = _selectedDevotionals.length == _filteredDevotionals.length;
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedDevotionals.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Delete'),
        content: Text('Are you sure you want to delete ${_selectedDevotionals.length} selected devotionals?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final id in _selectedDevotionals) {
          final devotional = _devotionals.firstWhere((d) => (d.id ?? d.title) == id);
          await _devotionalService.deleteDevotional(devotional.id ?? devotional.title);
        }

        await _loadDevotionals();
        _toggleSelectionMode();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully deleted ${_selectedDevotionals.length} devotionals')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting devotionals: $e')),
          );
        }
      }
    }
  }

  Future<void> _bulkEdit() async {
    if (_selectedDevotionals.isEmpty) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _BulkEditDialog(),
    );

    if (result != null) {
      try {
        for (final id in _selectedDevotionals) {
          final devotional = _devotionals.firstWhere((d) => (d.id ?? d.title) == id);

          String updatedTitle = devotional.title;
          if (result['title_prefix'] != null && result['title_prefix'].isNotEmpty) {
            updatedTitle = '${result['title_prefix']} ${devotional.title}';
          }

          final updatedDevotional = DevotionalModel(
            id: devotional.id,
            title: updatedTitle,
            content: devotional.content,
            verseReference: devotional.verseReference,
            verseText: devotional.verseText,
            prayer: devotional.prayer,
            reflectionQuestions: devotional.reflectionQuestions,
            date: devotional.date,
            author: result['author'] ?? devotional.author,
          );

          await _devotionalService.updateDevotional(updatedDevotional);
        }

        await _loadDevotionals();
        _toggleSelectionMode();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully updated ${_selectedDevotionals.length} devotionals')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating devotionals: $e')),
          );
        }
      }
    }
  }

  Future<void> _bulkExport() async {
    if (_selectedDevotionals.isEmpty) return;

    try {
      final selectedDevotionals = _devotionals
          .where((d) => _selectedDevotionals.contains(d.id ?? d.title))
          .toList();

      final jsonData = selectedDevotionals.map((d) => d.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      // For now, we'll show the JSON in a dialog
      // In a real app, you'd save this to a file
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Data'),
            content: SingleChildScrollView(
              child: SelectableText(jsonString),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting devotionals: $e')),
        );
      }
    }
  }

  Future<void> _editDevotional(DevotionalModel devotional) async {
    final result = await showDialog<DevotionalModel>(
      context: context,
      builder: (context) => DevotionalFormDialog(
        title: devotional.id == null || devotional.id!.isEmpty ? 'Add Devotional' : 'Edit Devotional',
        initialDevotional: devotional,
        onSave: (updatedDevotional) async {
          return updatedDevotional;
        },
      ),
    );

    if (result != null) {
      try {
        await _devotionalService.updateDevotional(result);
        await _loadDevotionals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Devotional updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating devotional: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDevotional(DevotionalModel devotional) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${devotional.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _devotionalService.deleteDevotional(devotional.id ?? devotional.title);
        await _loadDevotionals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Devotional deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting devotional: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedDevotionals.length} selected')
            : const Text('Devotional Admin'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(_selectAll ? Icons.deselect : Icons.select_all),
                  onPressed: _toggleSelectAll,
                  tooltip: _selectAll ? 'Deselect All' : 'Select All',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _bulkEdit();
                        break;
                      case 'delete':
                        _bulkDelete();
                        break;
                      case 'export':
                        _bulkExport();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Bulk Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 8),
                          Text('Export'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete All', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Selection Mode',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _editDevotional(DevotionalModel(
                    id: _uuid.v4(),
                    title: '',
                    content: '',
                    prayer: '',
                    reflectionQuestions: [],
                    date: DateTime.now(),
                  )),
                  tooltip: 'Add Devotional',
                ),
              ],
      ),
      body: Column(
        children: [
          // Search bar
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterDevotionals,
                decoration: InputDecoration(
                  hintText: 'Search devotionals...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterDevotionals('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // Statistics bar
          if (!_isSelectionMode && _devotionals.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  _buildStatChip('Total', _devotionals.length.toString(), Colors.blue),
                  const SizedBox(width: 12),
                  _buildStatChip('Filtered', _filteredDevotionals.length.toString(), Colors.green),
                  const Spacer(),
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDevotionals.isEmpty
                    ? _buildEmptyState()
                    : _buildDevotionalsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No devotionals found'
                : 'No devotionals available',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevotionalsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredDevotionals.length,
      itemBuilder: (context, index) {
        final devotional = _filteredDevotionals[index];
        final devotionalId = devotional.id ?? devotional.title;
        final isSelected = _selectedDevotionals.contains(devotionalId);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          child: ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleDevotionalSelection(devotionalId),
                  )
                : CircleAvatar(
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
                if (devotional.author != null)
                  Text(
                    'By: ${devotional.author}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            trailing: _isSelectionMode
                ? null
                : PopupMenuButton<String>(
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
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
            onTap: _isSelectionMode
                ? () => _toggleDevotionalSelection(devotionalId)
                : () => _editDevotional(devotional),
            onLongPress: !_isSelectionMode
                ? () {
                    _toggleSelectionMode();
                    _toggleDevotionalSelection(devotionalId);
                  }
                : null,
          ),
        );
      },
    );
  }
}

class _BulkEditDialog extends StatefulWidget {
  @override
  State<_BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<_BulkEditDialog> {
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  bool _updateAuthor = false;
  bool _updateTitle = false;

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Edit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text('Update Author'),
            value: _updateAuthor,
            onChanged: (value) {
              setState(() {
                _updateAuthor = value ?? false;
              });
            },
          ),
          if (_updateAuthor)
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Update Title Prefix'),
            value: _updateTitle,
            onChanged: (value) {
              setState(() {
                _updateTitle = value ?? false;
              });
            },
          ),
          if (_updateTitle)
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title Prefix',
                hintText: 'Text to add before title',
                border: OutlineInputBorder(),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = <String, dynamic>{};
            if (_updateAuthor) {
              result['author'] = _authorController.text.trim();
            }
            if (_updateTitle) {
              result['title_prefix'] = _titleController.text.trim();
            }
            Navigator.pop(context, result.isNotEmpty ? result : null);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}