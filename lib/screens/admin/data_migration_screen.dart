import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/firebase_data_migration.dart';
import '../../services/auth_service.dart';

class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({super.key});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  bool _isMigrating = false;
  bool _isDataMigrated = false;
  Map<String, int> _stats = {};
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    try {
      final isAlreadyMigrated = await FirebaseDataMigration.isDataAlreadyMigrated();
      final stats = await FirebaseDataMigration.getMigrationStats();

      setState(() {
        _isDataMigrated = isAlreadyMigrated;
        _stats = stats;
        _statusMessage = isAlreadyMigrated
            ? 'Devotionals have already been migrated to Firebase'
            : 'Devotional migration not completed';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking migration status: $e';
      });
    }
  }

  Future<void> _startMigration() async {
    if (_isMigrating) return;

    // Check if user is authenticated (optional security check)
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first to perform migration')),
      );
      return;
    }

    setState(() {
      _isMigrating = true;
      _statusMessage = 'Starting migration...';
    });

    try {
      await FirebaseDataMigration.migrateAllData();

      // Refresh stats after migration
      final newStats = await FirebaseDataMigration.getMigrationStats();

      setState(() {
        _isMigrating = false;
        _isDataMigrated = true;
        _stats = newStats;
        _statusMessage = 'Devotional migration completed successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Devotional migration completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isMigrating = false;
        _statusMessage = 'Migration failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cleanData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clean Devotional Data'),
        content: const Text(
          'This will delete ALL devotional data from Firebase. '
          'This action cannot be undone. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _statusMessage = 'Cleaning data...';
    });

    try {
      await FirebaseDataMigration.cleanAllData();
      await _checkMigrationStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 Devotional data cleaned successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Cleaning failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devotional Migration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Migration Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isDataMigrated ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_stats.isNotEmpty) ...[
                      const Text(
                        'Current Data Count:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._stats.entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                            Text(
                              entry.value.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Migration Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isMigrating ? null : _startMigration,
                icon: _isMigrating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isMigrating ? 'Migrating...' : 'Migrate Devotionals'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Clean Data Button (for testing)
            if (_isDataMigrated)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cleanData,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Clean Devotional Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Information Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Migration Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• This will transfer devotional data to Firebase Firestore\n'
                      '• Bible data remains in local JSON files for faster access\n'
                      '• Safe to run multiple times (updates existing data)\n'
                      '• Requires internet connection and Firebase access\n'
                      '• Devotional migration is quick (usually under 1 minute)',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}