import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current user from the auth provider
    final user = ref.watch(authProvider);

    // Fetch additional user data from the Supabase profiles table
    final userProfile = ref.watch(
        userProfileProvider(user?.id)); // Assuming you have a profile provider

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/home');
          },
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : userProfile.when(
              data: (profile) => ListView(
                children: [
                  // Profile Picture Section (example placeholder)
                  ListTile(
                    leading: const Icon(Icons.account_circle, size: 50),
                    title: Text(
                      profile?.name ?? 'No Name',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(user.email ?? 'No Email'),
                  ),
                  const Divider(),
                  // Settings Button (navigate to Settings Screen)
                  ListTile(
                    title: const Text(
                      'Update Profile',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      context.go('/settings');
                    },
                  ),
                  const Divider(),
                  // Logout Button
                  ListTile(
                    title: const Text(
                      'Logout',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    leading: const Icon(Icons.logout),
                    onTap: () {
                      _showLogoutConfirmation(context, ref);
                    },
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Error: $error')),
            ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
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
