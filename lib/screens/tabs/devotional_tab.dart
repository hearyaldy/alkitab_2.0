// lib/screens/tabs/devotional_tab.dart

import 'dart:async'; // Import for Timer class
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/enhanced_devotional_card.dart';

import '../../models/devotional_model.dart';
import '../../services/devotional_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/sync_queue_processor.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import 'package:go_router/go_router.dart';

class DevotionalTab extends StatefulWidget {
  const DevotionalTab({super.key});

  @override
  State<DevotionalTab> createState() => _DevotionalTabState();
}

class _DevotionalTabState extends State<DevotionalTab> {
  bool _isLoading = false;
  bool _hasError = false;

  List<DevotionalModel> _allDevotionals = [];
  DevotionalModel? _todayDevotional;

  Timer? _autoSaveTimer; // Fixed: Declare as class property with proper type

  final AdminService _adminService = AdminService();
  bool _isAdmin = false;

  final TextEditingController _notesController = TextEditingController();

  Set<String> _bookmarkedVerses = {};

  final DevotionalService _devotionalService = DevotionalService();
  late final BookmarkService _bookmarkService;

  @override
  void initState() {
    super.initState();
    _bookmarkService = BookmarkService(SyncQueueProcessor());
    _loadDevotionals();
    _loadBookmarkedVerses();
    _loadSavedNote();
    _checkAdminStatus();

    // Setup auto-save timer for notes
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_notesController.text.isNotEmpty) {
        _saveNote(_notesController.text);
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin;
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel(); // Cancel timer when disposing
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedNote() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('my_devotional_note');
    if (saved != null) _notesController.text = saved;
  }

  Future<void> _saveNote(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_devotional_note', value);
  }

  Future<void> _loadDevotionals() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Use the service instead of directly fetching
      final devotionals = await _devotionalService.getAllDevotionals();
      final todayDevo = await _devotionalService.getTodayDevotional();

      setState(() {
        _allDevotionals = devotionals;
        _todayDevotional = todayDevo;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading devotionals: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookmarkedVerses() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final bookmarks =
          await _bookmarkService.getUserBookmarks(type: 'devotional');
      setState(() {
        _bookmarkedVerses = {
          for (final bookmark in bookmarks)
            if (bookmark.verseReference != null) bookmark.verseReference!
        };
      });
    } catch (e) {
      debugPrint('Failed to load bookmarks: $e');
    }
  }

  Future<void> _bookmarkDevotional(DevotionalModel devotional) async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to bookmark.')),
      );
      return;
    }

    final verseRef = devotional.verseReference;
    if (verseRef == null || _bookmarkedVerses.contains(verseRef)) return;

    try {
      final bookmark = await _bookmarkService.addBookmark(
        title: devotional.title,
        verseReference: verseRef,
        bookmarkType: 'devotional',
        type: 'devotional',
        devotionalText: devotional.content,
        prayer: devotional.prayer,
        reflectionQuestions: devotional.reflectionQuestions.isNotEmpty
            ? {'questions': devotional.reflectionQuestions}
            : null,
        bookId: '',
        chapterId: 0,
        verseId: 0,
      );

      if (bookmark != null) {
        setState(() => _bookmarkedVerses.add(verseRef));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devotional bookmarked!')),
        );
        debugPrint('Bookmark inserted: $verseRef');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to bookmark devotional.')),
        );
      }
    } catch (e) {
      debugPrint('Bookmark error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bookmark error: $e')),
      );
    }
  }

  void _showDevotionalDetails(DevotionalModel devotional) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    devotional.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (devotional.verseReference != null)
                    Text(
                      devotional.verseReference!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 16),
                  Text(devotional.content, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 16),
                  const Text('Prayer:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(devotional.prayer,
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 160,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
            title: const Text(
              'Daily Devotional',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/header_image.png',
                  fit: BoxFit.cover, // Fixed: coverfit -> cover
                ),
                Container(color: Colors.black.withValues(alpha: 0.5)),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search devotionals',
              onPressed: () => context.push('/devotional-search'),
            ),
            if (_isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Devotional Admin',
                onPressed: () => context.push('/admin/devotionals'),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh devotionals',
              onPressed: () {
                _devotionalService.refreshCache();
                _loadDevotionals();
              },
            ),
          ],
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_hasError)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Oops! Failed to load devotionals.\nPlease try again later.',
                  textAlign: TextAlign.center,
                ),
              )
            else if (_allDevotionals.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No devotionals found.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              if (_todayDevotional != null)
                EnhancedDevotionalCard(
                  devotional: _todayDevotional!,
                  isBookmarked: _bookmarkedVerses
                      .contains(_todayDevotional!.verseReference),
                  onBookmark: () => _bookmarkDevotional(_todayDevotional!),
                  notesController: _notesController,
                  onNoteChanged: _saveNote,
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Previous Devotionals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ..._allDevotionals
                  .where((dev) => dev != _todayDevotional)
                  .take(5)
                  .map((dev) {
                final verseRef = dev.verseReference ?? '';
                return ListTile(
                  title: Text(dev.title),
                  subtitle: Text(verseRef),
                  trailing: IconButton(
                    icon: Icon(
                      _bookmarkedVerses.contains(verseRef)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    onPressed: () => _bookmarkDevotional(dev),
                  ),
                  onTap: () => _showDevotionalDetails(dev),
                );
              }),
            ]
          ]),
        ),
      ],
    );
  }
}
