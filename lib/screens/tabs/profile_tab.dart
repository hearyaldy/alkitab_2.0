import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  _ProfileTabState createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Placeholders for additional metadata.
  String _lastLogin = 'Not available';
  String _lastPasswordChange = 'Not available';

  File? _profileImage;

  final user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    final userMeta = user?.userMetadata;
    _nameController = TextEditingController(text: userMeta?['full_name'] ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _lastLogin = user?.lastSignInAt ?? 'Not available';
    _lastPasswordChange =
        'Not available'; // Replace with real data if available.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Compress the image using flutter_image_compress.
  Future<File?> compressImage(File file) async {
    final targetPath =
        '${file.parent.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
    final dynamic result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
    );
    if (result == null) return null;
    return File(result.path);
  }

  // Allow the user to pick a new profile image.
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final compressed = await compressImage(file);
      if (compressed != null) {
        setState(() {
          _profileImage = compressed;
        });
        final userId = Supabase.instance.client.auth.currentUser!.id;
        await _uploadProfilePhoto(compressed, userId);
      }
    }
  }

  // Upload the profile image to your Supabase bucket.
  Future<void> _uploadProfilePhoto(File imageFile, String userId) async {
    final fileName = 'profile_photos/profile_$userId.jpg';
    try {
      await Supabase.instance.client.storage.from('profile_photos').upload(
          fileName, imageFile,
          fileOptions: const FileOptions(upsert: true));
      final publicUrl = Supabase.instance.client.storage
          .from('profile_photos')
          .getPublicUrl(fileName);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile photo updated.\nURL: $publicUrl')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload error: $e')));
    }
  }

  // Update profile (only display name editable; email remains read-only).
  Future<void> _updateProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      final newName = _nameController.text.trim();
      try {
        final response = await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            email: _emailController.text,
            data: {'full_name': newName},
          ),
        );
        if (response.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated successfully.")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile update failed.")));
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a CustomScrollView for collapsible header and content
      body: CustomScrollView(
        slivers: [
          // Collapsible header similar to DevotionalTab header style.
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
                  Image.asset(
                    'assets/images/header_image.png',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.54),
                  ),
                ],
              ),
            ),
          ),
          // Main content area
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User image in content area.
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Display Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email field (read-only)
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
                    // Metadata cards
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
                    // Update and Logout buttons
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
