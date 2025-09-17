import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/profile_photo_provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

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
  String? _photoUrl;
  final UserService _userService = UserService();

  User? get user => AuthService.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _photoUrl = user?.photoURL;
    _lastLogin = user?.metadata.lastSignInTime?.toString() ?? 'Not available';
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
        final publicUrl = await _userService.uploadProfilePhoto(compressed);
        if (publicUrl != null) {
          await _userService.updateProfile(profilePhotoUrl: publicUrl);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_photo', publicUrl);
          ref.read(profilePhotoProvider.notifier).updateProfilePhoto(publicUrl);
          setState(() {
            _photoUrl = publicUrl;
          });
        }
      }
    }
  }


  Future<void> _updateProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newName = _nameController.text.trim();
      try {
        final result = await _userService.updateProfile(displayName: newName);
        if (result != null) {
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
      await AuthService.signOut();
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
