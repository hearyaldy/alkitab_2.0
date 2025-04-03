import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tabs/home_tab.dart';
import 'tabs/bible_tab.dart';
import 'tabs/devotional_tab.dart';
import 'tabs/profile_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int tabIndex;

  const HomeScreen(
      {super.key,
      required this.tabIndex,
      required StatefulNavigationShell shell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _selectedIndex;

  static final List<Widget> _tabs = [
    const HomeTab(),
    const BibleTab(),
    const DevotionalTab(),
    const ProfileTab(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alkitab 2.0'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Future: Add search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.go('/settings');
            },
          ),
        ],
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Utama'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Alkitab'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: 'Renungan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
