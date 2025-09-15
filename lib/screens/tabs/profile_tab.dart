import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/profile_photo_provider.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String _lastLogin = 'Not available';
  final String _lastPasswordChange = 'Not available';
  File? _profileImage;
  String? _photoUrl;

  final user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    final userMeta = user?.userMetadata;
    _nameController = TextEditingController(text: userMeta?['full_name'] ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _photoUrl = userMeta?['profile_url'];
    _lastLogin = user?.lastSignInAt ?? 'Not available';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<File?> compressImage(File file) async {
    final targetPath =
        '${file.parent.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
    );
    return result == null ? null : File(result.path);
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final compressed = await compressImage(file);
      if (compressed != null) {
        final userId = user!.id;
        final publicUrl = await _uploadProfilePhoto(compressed, userId);
        if (publicUrl != null) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'profile_url': publicUrl}),
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_photo', publicUrl);
          ref.read(profilePhotoProvider.notifier).updateProfilePhoto(publicUrl);
          setState(() {
            _profileImage = null;
            _photoUrl = publicUrl;
          });
        }
      }
    }
  }

  Future<String?> _uploadProfilePhoto(File imageFile, String userId) async {
    final fileName = 'profile-images/profile_$userId.jpg';
    try {
      await Supabase.instance.client.storage.from('profile-images').upload(
          fileName, imageFile,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Photo updated.')));
      return publicUrl;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newName = _nameController.text.trim();
      try {
        final response = await Supabase.instance.client.auth.updateUser(
          UserAttributes(
              email: _emailController.text, data: {'full_name': newName}),
        );
        if (response.user != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Profile updated.")));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Update failed.")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: const Text(
                'Profile',
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
                  Image.asset('assets/images/header_image.png',
                      fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.54)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue,
                          backgroundImage: _photoUrl != null
                              ? NetworkImage(_photoUrl!)
                              : null,
                          child: _photoUrl == null
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Please enter name'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: const Text('Last Login'),
                        subtitle: Text(_lastLogin),
                      ),
                    ),
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: const Text('Last Password Change'),
                        subtitle: Text(_lastPasswordChange),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      child: const Text('Update Profile'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _confirmLogout,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
