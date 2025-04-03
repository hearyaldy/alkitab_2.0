import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;
  double _fontSize = 16.0;
  String _bibleVersion = 'ABB';
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(
                '/home'); // You can change this to navigate to the desired page
          },
        ),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'Appearance',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
              });
              // In a real app, you'd update a theme provider here
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
                setState(() {
                  _fontSize = value;
                });
                // In a real app, you'd update a settings provider here
              },
            ),
            trailing: Text(
              _fontSize.toInt().toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'Bible',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          ListTile(
            title: const Text('Default Bible Version'),
            subtitle: Text(_bibleVersion == 'ABB'
                ? 'Alkitab Berita Baik'
                : 'Alkitab Terjemahan Baru'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showVersionSelectionDialog();
            },
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Verse of the Day'),
            subtitle: const Text('Receive daily verse notifications'),
            value: _notifications,
            onChanged: (value) {
              setState(() {
                _notifications = value;
              });
              // In a real app, you'd update a notifications provider here
            },
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'About',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to Terms of Service screen
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to Privacy Policy screen
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout),
            onTap: () {
              _showLogoutConfirmation();
            },
          ),
        ],
      ),
    );
  }

  void _showVersionSelectionDialog() {
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
                groupValue: _bibleVersion,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _bibleVersion = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Alkitab Terjemahan Baru (ATB)'),
                value: 'ATB',
                groupValue: _bibleVersion,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _bibleVersion = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
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
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              // ignore: use_build_context_synchronously
              context.go('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
