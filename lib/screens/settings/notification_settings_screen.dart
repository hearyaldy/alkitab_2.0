import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      await _notificationService.initialize();
      final status = await _notificationService.getNotificationStatus();

      setState(() {
        _notificationsEnabled = status['enabled'] ?? false;
        _hasPermissions = status['hasPermissions'] ?? false;
        final timeString = status['time'] ?? '08:00';
        final parts = timeString.split(':');
        _notificationTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled && !_hasPermissions) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _hasPermissions = true);
    }

    setState(() => _notificationsEnabled = enabled);
    await _notificationService.setNotificationsEnabled(enabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Daily notifications enabled!'
              : 'Daily notifications disabled',
        ),
        backgroundColor: enabled ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _selectNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _notificationTime) {
      setState(() => _notificationTime = picked);
      await _notificationService.setNotificationTime(picked);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notification time updated to ${picked.format(context)}',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showNotification(
      title: 'Test Notification 📱',
      body: 'This is a test notification from Alkitab 2.0!',
      payload: 'test',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _sendEncouragement() async {
    await _notificationService.sendEncouragementNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Encouragement notification sent!'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notifications Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _notificationsEnabled
                                    ? Icons.notifications_active
                                    : Icons.notifications_off,
                                color: _notificationsEnabled
                                    ? Colors.green
                                    : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Daily Devotional Notifications',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _notificationsEnabled
                                          ? 'Enabled at ${_notificationTime.format(context)}'
                                          : 'Disabled',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: _toggleNotifications,
                              ),
                            ],
                          ),
                          if (!_hasPermissions && _notificationsEnabled) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange[600]),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Notification permission is required',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notification Time Setting
                  if (_notificationsEnabled) ...[
                    const Text(
                      'Notification Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Notification Time'),
                        subtitle: Text('Daily reminder at ${_notificationTime.format(context)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _selectNotificationTime,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Test Section
                  const Text(
                    'Test Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.play_circle_outline, color: Colors.blue),
                          title: const Text('Test Notification'),
                          subtitle: const Text('Send a test notification now'),
                          trailing: ElevatedButton(
                            onPressed: _testNotification,
                            child: const Text('Test'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.favorite, color: Colors.purple),
                          title: const Text('Test Encouragement'),
                          subtitle: const Text('Send an encouragement notification'),
                          trailing: ElevatedButton(
                            onPressed: _sendEncouragement,
                            child: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Information Section
                  const Text(
                    'About Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoItem(
                            Icons.schedule,
                            'Daily Reminders',
                            'Get reminded to read your daily devotional',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            Icons.favorite_outline,
                            'Encouragement Messages',
                            'Receive weekly encouragement and inspiration',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            Icons.privacy_tip_outlined,
                            'Privacy',
                            'Notifications are generated locally on your device',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}