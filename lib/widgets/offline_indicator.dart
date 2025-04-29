// lib/widgets/offline_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_providers.dart';
import '../utils/offline_manager.dart';

class OfflineIndicator extends ConsumerWidget {
  final bool showReconnectButton;
  final bool animated;
  final double elevation;

  const OfflineIndicator({
    super.key,
    this.showReconnectButton = true,
    this.animated = true,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(connectivityProvider);
    final syncQueueStatus = ref.watch(syncQueueStatusProvider);

    return isOnlineAsync.when(
      data: (isOnline) {
        if (isOnline) return const SizedBox.shrink();

        return syncQueueStatus.when(
          data: (items) {
            return _buildOfflineIndicator(
              context: context,
              pendingItems: items.length,
            );
          },
          loading: () => _buildLoadingIndicator(),
          error: (_, __) => _buildErrorIndicator(),
        );
      },
      loading: () => _buildLoadingIndicator(),
      error: (_, __) => _buildErrorIndicator(),
    );
  }

  Widget _buildOfflineIndicator({
    required BuildContext context,
    required int pendingItems,
  }) {
    return AnimatedContainer(
      duration: animated ? const Duration(milliseconds: 300) : Duration.zero,
      child: Material(
        elevation: elevation,
        child: Container(
          width: double.infinity,
          color: Colors.red.shade700,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'You are offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      pendingItems > 0
                          ? '$pendingItems items waiting to sync when online'
                          : 'Some features may be limited',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (showReconnectButton)
                TextButton(
                  onPressed: () {
                    // Try to check connection again
                    OfflineManager().checkConnectivity();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checking connection...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(60, 28),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Reconnect'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox.shrink();
  }

  Widget _buildErrorIndicator() {
    return Material(
      elevation: elevation,
      child: Container(
        width: double.infinity,
        color: Colors.amber.shade700,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Cannot determine connection status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A smaller, more compact offline indicator
class CompactOfflineIndicator extends ConsumerWidget {
  const CompactOfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(connectivityProvider);

    return isOnlineAsync.when(
      data: (isOnline) {
        if (isOnline) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 12, color: Colors.red.shade700),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
