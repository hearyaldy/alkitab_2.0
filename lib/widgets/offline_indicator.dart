// lib/widgets/offline_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/offline_manager.dart';

/// A widget that shows an animated offline indicator when the user is offline
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
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
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
          child: Container(
            width: double.infinity,
            color: Colors.redAccent,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You are offline. Some features may be limited.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
