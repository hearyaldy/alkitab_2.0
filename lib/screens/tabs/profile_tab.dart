import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = Colors.indigo;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.indigo,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'user@example.com',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('My Content', themeColor),
        _settingItem(Icons.book, 'Reading History'),
        _settingItem(Icons.bookmark, 'Bookmarks'),
        _settingItem(Icons.highlight, 'Highlights'),
        _settingItem(Icons.note, 'Notes'),
        const SizedBox(height: 24),
        _sectionTitle('Settings', themeColor),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('App Settings'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => context.go('/settings'),
        ),
        const Divider(height: 1),
        const SizedBox(height: 24),
        _sectionTitle('Account', themeColor),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          color: color.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _settingItem(IconData icon, String title) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.indigo),
          title: Text(title),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // Navigate to details
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
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
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  get shade700 => null;
}
