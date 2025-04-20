import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/bible_version_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  double _fontSize = 16.0;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 16.0;
      _notifications = prefs.getBool('notifications') ?? true;
    });

    // Apply settings to providers
    ref.read(themeProvider.notifier).setTheme(
          _darkMode ? ThemeMode.dark : ThemeMode.light,
        );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setBool('notifications', _notifications);
  }

  @override
  Widget build(BuildContext context) {
    final bibleVersion = ref.watch(bibleVersionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Appearance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              ref.read(themeProvider.notifier).setTheme(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('Text Size'),
            subtitle: Slider(
              value: _fontSize,
              min: 12.0,
              max: 28.0,
              divisions: 8,
              label: _fontSize.toInt().toString(),
              onChanged: (value) {
                setState(() => _fontSize = value);
                _saveSettings();
              },
            ),
            trailing: Text(
              _fontSize.toInt().toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Bible',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            title: const Text('Default Bible Version'),
            subtitle: Text(bibleVersion == 'ABB'
                ? 'Alkitab Berita Baik'
                : 'Alkitab Terjemahan Baru'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showVersionSelectionDialog,
          ),
          const Divider(),
          const ListTile(
            title: Text('Notifications',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SwitchListTile(
            title: const Text('Verse of the Day'),
            subtitle: const Text('Receive daily verse notifications'),
            value: _notifications,
            onChanged: (value) {
              setState(() => _notifications = value);
              _saveSettings();
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('About',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout),
            onTap: _showLogoutConfirmation,
          ),
        ],
      ),
    );
  }

  void _showVersionSelectionDialog() {
    final version = ref.read(bibleVersionProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Bible Version'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Alkitab Berita Baik (ABB)'),
                value: 'ABB',
                groupValue: version,
                onChanged: (value) {
                  Navigator.pop(context);
                  ref.read(bibleVersionProvider.notifier).setVersion(value!);
                },
              ),
              RadioListTile<String>(
                title: const Text('Alkitab Terjemahan Baru (ATB)'),
                value: 'ATB',
                groupValue: version,
                onChanged: (value) {
                  Navigator.pop(context);
                  ref.read(bibleVersionProvider.notifier).setVersion(value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
