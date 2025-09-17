// lib/screens/tabs/home_tab.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/bible_data.dart';
import '../../services/mock_data_service.dart';
import '../../services/auth_service.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  late Future<void> _initializationFuture;
  final ImageProvider _headerImage =
      const AssetImage('assets/images/header_image.png');

  List<Map<String, dynamic>> _devotionals = [];
  Map<String, dynamic>? _todayDevo;
  List<Map<String, dynamic>> _recentReadings = [];
  Map<String, dynamic>? _bibleData;
  int _totalVerses = 0;
  String _randomVerse = '';
  String _randomVerseRef = '';

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeData();

    // Listen to auth state changes to rebuild UI
    AuthService.authStateChanges.listen((User? user) {
      if (mounted) {
        setState(() {
          // Trigger rebuild when auth state changes
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_headerImage, context);
  }

  Future<void> _initializeData() async {
    await _loadBibleData();
    await _loadDevotionals();
    await _loadReadingHistory();
  }

  Future<void> _loadBibleData() async {
    try {
      final String response = await rootBundle.loadString('assets/bibles/indo_tb.json');
      _bibleData = json.decode(response);

      final List<dynamic> verses = _bibleData?['verses'] ?? [];
      _totalVerses = verses.length;

      // Get random verse for today
      final now = DateTime.now();
      final randomIndex = (now.day + now.month + now.year) % verses.length;
      final randomVerseData = verses[randomIndex];
      _randomVerse = randomVerseData['text'] ?? '';
      _randomVerseRef = '${randomVerseData['book_name']} ${randomVerseData['chapter']}:${randomVerseData['verse']}';

      debugPrint('Loaded Bible data: $_totalVerses verses');
    } catch (e) {
      debugPrint('Error loading Bible data: $e');
    }
  }

  Future<void> _loadDevotionals({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDevosJson = prefs.getString('cached_devotionals');
    final cacheTimestamp = prefs.getInt('cached_devotionals_time');

    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheValid = cacheTimestamp != null &&
        (now - cacheTimestamp) < 7 * 24 * 60 * 60 * 1000;

    if (!forceRefresh && cachedDevosJson != null && cacheValid) {
      try {
        final List<dynamic> parsed = jsonDecode(cachedDevosJson);
        _devotionals = parsed.cast<Map<String, dynamic>>();
        _todayDevo = _pickTodayDevo(_devotionals);
        debugPrint('Loaded devotionals from cache.');
        return;
      } catch (e) {
        debugPrint('Error parsing cached devotionals: $e');
      }
    }

    try {
      final storage = FirebaseStorage.instance;
      final listResult = await storage.ref('devotional-readings').listAll();
      final List<Map<String, dynamic>> combined = [];

      for (final item in listResult.items) {
        if (!item.name.endsWith('.json')) continue;
        try {
          final data = await item.getData();
          if (data != null) {
            final jsonData = jsonDecode(utf8.decode(data));
            if (jsonData is List) {
              combined.addAll(jsonData.cast<Map<String, dynamic>>());
            }
          }
        } catch (e) {
          debugPrint('Error loading file ${item.name}: $e');
        }
      }

      if (combined.isNotEmpty) {
        _devotionals = combined;
        _todayDevo = _pickTodayDevo(combined);

        await prefs.setString('cached_devotionals', jsonEncode(_devotionals));
        await prefs.setInt('cached_devotionals_time', now);

        debugPrint('Downloaded and cached devotionals.');
        return;
      }
    } catch (e) {
      debugPrint('Error loading devotionals from Firebase: $e');
    }

    // Fallback to mock data
    debugPrint('Using mock devotional data for home tab.');
    await MockDataService.initialize();
    final mockDevotionals = MockDataService.getDevotionals();
    _devotionals = mockDevotionals.map((d) => d.toJson()).toList();
    _todayDevo = _pickTodayDevo(_devotionals);

    await prefs.setString('cached_devotionals', jsonEncode(_devotionals));
    await prefs.setInt('cached_devotionals_time', now);
  }

  Map<String, dynamic>? _pickTodayDevo(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return null;
    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(now.year)).inDays % list.length;
    return list[dayIndex];
  }

  Future<void> _loadReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('last_readings') ?? [];
    _recentReadings = data
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList()
        .reversed
        .take(5)
        .toList();

    // If no reading history, use mock data
    if (_recentReadings.isEmpty) {
      await MockDataService.initialize();
      _recentReadings = MockDataService.getRecentReadings();
    }
  }

  Future<void> _refreshDevotionals() async {
    await _loadDevotionals(forceRefresh: true);
    setState(() {});
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devotionals refreshed.')),
        );
      });
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    final results = _searchBibleText(query);
    _showSearchResults(query, results);
  }

  List<Map<String, dynamic>> _searchBibleText(String query) {
    if (_bibleData == null) return [];

    final List<dynamic> verses = _bibleData?['verses'] ?? [];
    final results = <Map<String, dynamic>>[];

    for (final verse in verses) {
      if (verse is Map<String, dynamic> &&
          verse['text'] != null &&
          verse['text'].toString().toLowerCase().contains(query.toLowerCase())) {
        results.add({
          'text': verse['text'],
          'reference': '${verse['book_name']} ${verse['chapter']}:${verse['verse']}',
          'book_name': verse['book_name'],
          'chapter': verse['chapter'],
          'verse': verse['verse'],
        });
      }
    }

    return results.take(50).toList(); // Limit to 50 results
  }

  void _showSearchResults(String query, List<Map<String, dynamic>> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hasil Pencarian: "$query"',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${results.length} hasil',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada hasil ditemukan',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Coba kata kunci yang berbeda',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              // Navigate to the specific verse
                              final bookName = result['book_name'];
                              final chapter = result['chapter'];
                              final bookData = bibleBooks.firstWhere(
                                (book) => book['name'] == bookName,
                                orElse: () => bibleBooks.first,
                              );
                              context.go('/bible-reader?bookId=${bookData['id']}&chapterId=$chapter');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result['reference'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    result['text'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _refreshDevotionals,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: _buildMainContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar() {
    final now = DateTime.now();
    final formattedDate = DateFormat.yMMMMd('ms').format(now);
    final dayName = DateFormat('EEEE', 'ms').format(now);

    final user = AuthService.currentUser;
    final displayName = user?.displayName ?? user?.email ?? "Guest";
    final firstName = displayName.split(" ").first;
    final profileUrl = user?.photoURL;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshDevotionals,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alkitab 2.0',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(formattedDate,
                          style: const TextStyle(
                              fontSize: 8, color: Colors.white70)),
                      const Text(' | ',
                          style: TextStyle(fontSize: 8, color: Colors.white70)),
                      Text(dayName,
                          style: const TextStyle(
                              fontSize: 8, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: user != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              profileUrl != null ? NetworkImage(profileUrl) : null,
                          backgroundColor: Colors.white,
                          child: profileUrl == null
                              ? const Icon(Icons.person,
                                  size: 16, color: Colors.indigo)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text("Welcome, $firstName!",
                            style: const TextStyle(fontSize: 8, color: Colors.white)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.login,
                              size: 16,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Tap to Login",
                            style: const TextStyle(fontSize: 8, color: Colors.white)),
                      ],
                    ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: _headerImage, fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Search field under header
        _buildSearchField(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _verseOfDayCard(),
              const SizedBox(height: 24),
              _bibleStatsCard(),
              const SizedBox(height: 24),
              _bibleBooksSection(),
              const SizedBox(height: 24),
              _continueReadingSection(),
              const SizedBox(height: 24),
              _devotionalSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onSubmitted: (query) => _performSearch(query),
        decoration: InputDecoration(
          hintText: 'Cari ayat Alkitab atau kata...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.grey[600]),
            onSelected: (value) {
              // Handle filter selection
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'verse',
                child: Row(
                  children: [
                    Icon(Icons.format_quote),
                    SizedBox(width: 8),
                    Text('Cari Ayat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'word',
                child: Row(
                  children: [
                    Icon(Icons.text_fields),
                    SizedBox(width: 8),
                    Text('Cari Kata'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'book',
                child: Row(
                  children: [
                    Icon(Icons.book),
                    SizedBox(width: 8),
                    Text('Cari Kitab'),
                  ],
                ),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _verseOfDayCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4A90E2), // Beautiful blue
              const Color(0xFF357ABD), // Deeper blue
              const Color(0xFF2E6BA6), // Even deeper blue
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ayat Hari Ini',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      tooltip: 'Share verse',
                      onPressed: () {
                        final verse = _randomVerse.isNotEmpty ? _randomVerse : _todayDevo?['verse_text'] ?? '';
                        final reference = _randomVerseRef.isNotEmpty ? _randomVerseRef : _todayDevo?['verse_reference'] ?? '';
                        final content = '"$verse"\n\n📖 $reference\n\nDibagikan dari Alkitab 2.0';
                        SharePlus.instance.share(ShareParams(text: content, subject: 'Ayat Hari Ini'));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${_randomVerse.isNotEmpty ? _randomVerse : _todayDevo?['verse_text'] ?? 'Memuat ayat...'}"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        height: 1.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _randomVerseRef.isNotEmpty ? _randomVerseRef : _todayDevo?['verse_reference'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E6BA6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bibleStatsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics,
                    color: Theme.of(context).colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text('Bible Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Books', '66', Icons.book),
                _buildStatItem('Verses', _totalVerses.toString(), Icons.format_quote),
                _buildStatItem('Old Test.', '39', Icons.history_edu),
                _buildStatItem('New Test.', '27', Icons.auto_stories),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          )),
        Text(label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
          )),
      ],
    );
  }

  Widget _bibleBooksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Read the Bible',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showTestamentBooks('OT'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.history_edu,
                          size: 48,
                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(height: 8),
                        Text('Old Testament',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )),
                        Text('39 Books',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showTestamentBooks('NT'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.auto_stories,
                          size: 48,
                          color: Theme.of(context).colorScheme.onTertiaryContainer),
                        const SizedBox(height: 8),
                        Text('New Testament',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          )),
                        Text('27 Books',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.7),
                          )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTestamentBooks(String testament) {
    final books = testament == 'OT' ? getOldTestamentBooks() : getNewTestamentBooks();
    final title = testament == 'OT' ? 'Old Testament Books' : 'New Testament Books';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text('${index + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    title: Text(book['name']),
                    subtitle: Text('${book['chapters']} chapters'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/bible-reader?bookId=${book['id']}&chapterId=1');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _continueReadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Continue Reading',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._recentReadings.map((entry) {
          final book = entry['bookId'] ?? 'Unknown';
          final chapter = entry['chapterId'] ?? 1;
          final bookName = entry['bookName'] ?? book;
          final progress = (entry['progress'] ?? 0.0) as double;
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text('$bookName Chapter $chapter'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${(progress * 100).round()}% read'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: progress),
                ],
              ),
              onTap: () =>
                  context.go('/bible-reader?bookId=$book&chapterId=$chapter'),
            ),
          );
        }),
      ],
    );
  }

  Widget _devotionalSection() {
    final recentDevotionals = _devotionals.where((d) => d != _todayDevo).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Daily Devotionals',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.go('/devotional'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_todayDevo != null) ...[
          _buildTodayDevotionalCard(_todayDevo!),
          const SizedBox(height: 16),
        ],
        if (recentDevotionals.isNotEmpty) ...[
          const Text('Recent Devotionals',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...recentDevotionals.map((dev) => _buildDevotionalCard(dev)),
        ],
      ],
    );
  }

  Widget _buildTodayDevotionalCard(Map<String, dynamic> devo) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Today\'s Devotional',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      final title = devo['title'] ?? 'Today\'s Devotional';
                      final verse = devo['verse_reference'] ?? '';
                      final text = devo['devotional_text'] ?? '';
                      final prayer = devo['prayer'] ?? '';
                      final content = '''
$title
$verse

$text

🙏 $prayer

Shared from Alkitab 2.0''';
                      SharePlus.instance.share(ShareParams(text: content));
                    },
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                devo['title'] ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (devo['verse_reference'] != null)
                Text(
                  devo['verse_reference'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                (devo['devotional_text'] ?? '').length > 120
                    ? '${(devo['devotional_text'] ?? '').substring(0, 120)}...'
                    : devo['devotional_text'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _showDevotionalDetails(devo),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Read More'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevotionalCard(Map<String, dynamic> dev) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDevotionalDetails(dev),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dev['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              if (dev['verse_reference'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  dev['verse_reference'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (dev['devotional_text'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  (dev['devotional_text']).length > 80
                      ? '${(dev['devotional_text']).substring(0, 80)}...'
                      : dev['devotional_text'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDevotionalDetails(Map<String, dynamic> devo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(devo['title'] ?? 'Untitled',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(devo['verse_reference'] ?? '',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Text(devo['devotional_text'] ?? '',
                  style: const TextStyle(height: 1.5)),
              const SizedBox(height: 16),
              const Text('Prayer:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(devo['prayer'] ?? '',
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
        ),
      ),
    );
  }
}
