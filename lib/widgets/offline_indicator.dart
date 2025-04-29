// lib/widgets/offline_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/offline_manager.dart';

/// A widget that shows an animated offline indicator with retry button and last connected time
class OfflineIndicator extends ConsumerStatefulWidget {
  const OfflineIndicator({Key? key}) : super(key: key);

  @override
  ConsumerState<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends ConsumerState<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  bool _isVisible = false;
  DateTime? _lastConnected;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleStatusChange(OfflineStatus status) {
    if (status.isOffline && !_isVisible) {
      _isVisible = true;
      _controller.forward();
    } else if (!status.isOffline && _isVisible) {
      _lastConnected = DateTime.now();
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minute(s) ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour(s) ago';
    } else {
      return '${difference.inDays} day(s) ago';
    }
  }

  Future<void> _retryConnection() async {
    final offlineManager = OfflineManager();
    // Simulate manual recheck by triggering the status update
    offlineManager.initialize(); // Re-initialize to simulate recheck
  }

  @override
  Widget build(BuildContext context) {
    final offlineManager = OfflineManager();

    return StreamBuilder<OfflineStatus>(
      stream: offlineManager.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;

        if (status == null) {
          return const SizedBox.shrink();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleStatusChange(status);
        });

        return SlideTransition(
          position: _offsetAnimation,
          child: Material(
            elevation: 6,
            child: Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You are offline. Some features may be limited.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _retryConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  if (_lastConnected != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last connected: ${_formatTimeAgo(_lastConnected!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
