import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tabs/home_tab.dart' as home;
import 'tabs/bible_tab.dart';
import 'tabs/devotional_tab.dart';
import 'tabs/profile_tab.dart' as profile;

class HomeScreen extends ConsumerStatefulWidget {
  final int tabIndex;

  const HomeScreen({
    super.key,
    required this.tabIndex,
    required StatefulNavigationShell shell,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _selectedIndex;
  bool _isFloatingMenuOpen = false;

  static final List<Widget> _tabs = [
    const home.HomeTab(),
    const BibleTab(),
    const DevotionalTab(),
    const profile.ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.tabIndex;
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/bible');
          break;
        case 2:
          context.go('/devotional');
          break;
        case 3:
          context.go('/profile');
          break;
      }
    }
  }

  void _toggleFloatingMenu() {
    setState(() {
      _isFloatingMenuOpen = !_isFloatingMenuOpen;
    });
  }

  void _onSettingsPressed() {
    setState(() {
      _isFloatingMenuOpen = false;
    });
    context.go('/settings');
  }

  void _onBookmarkPressed() {
    setState(() {
      _isFloatingMenuOpen = false;
    });
    context.go('/bookmarks');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.disabledColor,
        backgroundColor: theme.colorScheme.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Utama'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Alkitab'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: 'Renungan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          if (_isFloatingMenuOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'bookmark',
                    mini: true,
                    onPressed: _onBookmarkPressed,
                    tooltip: 'Bookmarks',
                    child: const Icon(Icons.bookmark),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'settings',
                    mini: true,
                    onPressed: _onSettingsPressed,
                    tooltip: 'Settings',
                    child: const Icon(Icons.settings),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          FloatingActionButton(
            heroTag: 'mainMenu',
            onPressed: _toggleFloatingMenu,
            tooltip: 'Menu',
            child: Icon(_isFloatingMenuOpen ? Icons.close : Icons.menu),
          ),
        ],
      ),
    );
  }
}
