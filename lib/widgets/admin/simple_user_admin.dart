// lib/widgets/admin/simple_user_admin.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';

class SimpleUserAdminWidget extends StatefulWidget {
  const SimpleUserAdminWidget({super.key});

  @override
  State<SimpleUserAdminWidget> createState() => _SimpleUserAdminWidgetState();
}

class _SimpleUserAdminWidgetState extends State<SimpleUserAdminWidget> {
  final AdminService _adminService = AdminService();
  final TextEditingController _emailController = TextEditingController();
  List<Map<String, dynamic>> _adminUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminUsers() async {
    if (!_adminService.isSuperadmin) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _adminService.getAdminUsers();
      setState(() {
        _adminUsers = users;
      });
    } catch (e) {
      debugPrint('Error loading admin users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addAdmin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a role entry for the email that will be activated when user signs in
      final firebase = FirebaseFirestore.instance;

      // Create a user role document with the email as identifier
      await firebase.collection('pending_admin_emails').doc(email).set({
        'email': email,
        'role': 'admin',
        'created_at': FieldValue.serverTimestamp(),
        'created_by': 'superadmin',
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin role pending for $email. They will have admin privileges when they sign in.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _emailController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding admin role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeAdmin(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Admin'),
        content: Text('Remove admin privileges from $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Remove from user_roles collection
        await _adminService.setUserRole(userId, UserRole.user);
        await _loadAdminUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed admin privileges from $email')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing admin: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_adminService.isSuperadmin) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.admin_panel_settings, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Superadmin Access Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Only the superadmin can manage user roles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.people, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'Admin User Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Add admin section
              const Text(
                'Add New Admin',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'Enter email address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current admins section
              Row(
                children: [
                  const Text(
                    'Current Admins',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadAdminUsers,
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_adminUsers.isEmpty && !_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No admin users found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...List.generate(_adminUsers.length, (index) {
                  final user = _adminUsers[index];
                  final email = user['email'] as String? ?? 'Unknown';
                  final role = user['role'] as String? ?? 'admin';
                  final isSuperadmin = role == 'superadmin';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSuperadmin ? Colors.red : Colors.purple,
                        child: Icon(
                          isSuperadmin ? Icons.admin_panel_settings : Icons.security,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(email),
                      subtitle: Text(
                        isSuperadmin ? 'Superadmin' : 'Admin',
                        style: TextStyle(
                          color: isSuperadmin ? Colors.red : Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: isSuperadmin
                          ? const Chip(
                              label: Text('SUPER', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.red,
                              labelStyle: TextStyle(color: Colors.white),
                            )
                          : IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeAdmin(user['id'], email),
                            ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}