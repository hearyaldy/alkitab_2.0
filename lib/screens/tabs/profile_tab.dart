import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userMeta = user?.userMetadata;

    final name = userMeta?['full_name'] ?? 'No name set';
    final email = user?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.person, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            Text(name, style: const TextStyle(fontSize: 24)),
            Text(email, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
