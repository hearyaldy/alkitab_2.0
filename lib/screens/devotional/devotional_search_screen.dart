import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/devotional_model.dart';
import '../../services/search_service.dart';
import '../../widgets/enhanced_devotional_card.dart';
import '../../services/bookmark_service.dart';
import '../../services/sync_queue_processor.dart';
import '../../services/auth_service.dart';
import '../../services/lazy_loading_service.dart';

class DevotionalSearchScreen extends ConsumerStatefulWidget {
  const DevotionalSearchScreen({super.key});

  @override
  ConsumerState<DevotionalSearchScreen> createState() => _DevotionalSearchScreenState();
}

class _DevotionalSearchScreenState extends ConsumerState<DevotionalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final SearchService _searchService = SearchService();
  late final BookmarkService _bookmarkService;

  List<DevotionalModel> _searchResults = [];
  List<String> _searchSuggestions = [];
  LazyListController<DevotionalModel>? _lazyController;
  bool _isLoading = false;
  bool _showSuggestions = false;
  Set<String> _bookmarkedVerses = {};

  @override
  void initState() {
    super.initState();
    _bookmarkService = BookmarkService(SyncQueueProcessor());
    _initializeSearch();
    _loadBookmarkedVerses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _lazyController?.dispose();
    super.dispose();
  }

  Future<void> _initializeSearch() async {
    await _searchService.initialize();
    await _loadPopularTerms();
  }

  Future<void> _loadPopularTerms() async {
    try {
      final popularTerms = await _searchService.getPopularSearchTerms();
      if (mounted) {
        setState(() {
          _searchResults = [];
          // Show popular terms as search suggestions
        });
      }
    } catch (e) {
      debugPrint('Error loading popular terms: $e');
    }
  }

  Future<void> _loadBookmarkedVerses() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final bookmarks = await _bookmarkService.getUserBookmarks(type: 'devotional');
      if (mounted) {
        setState(() {
          _bookmarkedVerses = {
            for (final bookmark in bookmarks)
              if (bookmark.verseReference != null) bookmark.verseReference!
          };
        });
      }
    } catch (e) {
      debugPrint('Failed to load bookmarks: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    try {
      final results = await _searchService.searchDevotionals(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;

          // Create lazy loading controller for large result sets
          if (results.length > 20) {
            _lazyController?.dispose();
            _lazyController = LazyListController<DevotionalModel>(
              fullList: results,
              pageSize: 15,
              threshold: 5,
            );
          } else {
            _lazyController?.dispose();
            _lazyController = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions = [];
      });
      return;
    }

    try {
      final suggestions = await _searchService.getSearchSuggestions(query);
      if (mounted) {
        setState(() {
          _searchSuggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
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
      );

      if (bookmark != null && mounted) {
        setState(() => _bookmarkedVerses.add(verseRef));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devotional bookmarked!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bookmark error: $e')),
        );
      }
    }
  }

  void _saveNote(String value) {
    // Notes are handled per devotional in the enhanced card
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Devotionals'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _loadSuggestions(value);
                // Perform search with debouncing
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _performSearch(value);
                  }
                });
              },
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search devotionals, topics, verses...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search suggestions
          if (_showSuggestions && _searchSuggestions.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _searchSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _searchSuggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(suggestion),
                      onPressed: () {
                        _searchController.text = suggestion;
                        _performSearch(suggestion);
                      },
                    ),
                  );
                },
              ),
            ),

          // Search results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? _buildNoResults()
                    : _searchResults.isEmpty
                        ? _buildSearchPrompt()
                        : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No devotionals found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or browse popular topics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Search Devotionals',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Search by topic, verse reference, or keywords',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Faith',
              'Hope',
              'Love',
              'Prayer',
              'Peace',
              'Joy',
              'Strength',
              'Wisdom',
            ].map((topic) => ActionChip(
              label: Text(topic),
              onPressed: () {
                _searchController.text = topic;
                _performSearch(topic);
              },
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // Use lazy loading for large result sets
    if (_lazyController != null) {
      return OptimizedListWidget<DevotionalModel>(
        controller: _lazyController!,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, devotional, index) {
          return EnhancedDevotionalCard(
            devotional: devotional,
            isBookmarked: _bookmarkedVerses.contains(devotional.verseReference),
            onBookmark: () => _bookmarkDevotional(devotional),
            notesController: _notesController,
            onNoteChanged: _saveNote,
          );
        },
        loadingIndicator: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading more devotionals...'),
              ],
            ),
          ),
        ),
      );
    }

    // Use regular ListView for smaller result sets
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final devotional = _searchResults[index];
        return EnhancedDevotionalCard(
          devotional: devotional,
          isBookmarked: _bookmarkedVerses.contains(devotional.verseReference),
          onBookmark: () => _bookmarkDevotional(devotional),
          notesController: _notesController,
          onNoteChanged: _saveNote,
        );
      },
    );
  }
}