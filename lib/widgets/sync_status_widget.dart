// lib/widgets/sync_status_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/offline_manager.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_providers.dart';

/// A widget that displays the current sync status of the app
class SyncStatusWidget extends ConsumerWidget {
  final bool showSyncButton;

  const SyncStatusWidget({
    Key? key,
    this.showSyncButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(connectivityProvider);
    final syncQueueStatus = ref.watch(syncQueueStatusProvider);

    // Get offline manager instance
    final offlineManager = OfflineManager();

    return isOnlineAsync.when(
      data: (isOnline) {
        return syncQueueStatus.when(
          data: (items) {
            // If there are no pending items and we're online, show just a minimal indicator
            if (items.isEmpty && isOnline) {
              return const SizedBox.shrink();
            }

            // We're offline or have pending items to sync
            Color backgroundColor =
                isOnline ? Colors.orange.shade100 : Colors.red.shade100;
            Color iconColor =
                isOnline ? Colors.orange.shade700 : Colors.red.shade700;
            Color textColor =
                isOnline ? Colors.orange.shade900 : Colors.red.shade900;
            IconData icon = isOnline ? Icons.sync : Icons.cloud_off;

            String message = isOnline
                ? '${items.length} items waiting to sync'
                : 'You are offline. Some features may be limited.';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: backgroundColor,
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                  ),
                  if (showSyncButton && isOnline && items.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final result = await offlineManager.manualSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Text('Sync Now'),
                      style: TextButton.styleFrom(
                        foregroundColor: iconColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(60, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => _buildLoadingIndicator(),
          error: (_, __) => _buildErrorIndicator(context),
        );
      },
      loading: () => _buildLoadingIndicator(),
      error: (_, __) => _buildErrorIndicator(context),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      height: 2,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const LinearProgressIndicator(
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.red.shade100,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Error checking connection status',
              style: TextStyle(color: Colors.red.shade900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that shows a detailed sync status in a card
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(connectivityProvider);
    final syncQueueStatus = ref.watch(syncQueueStatusProvider);

    // Get offline manager instance
    final offlineManager = OfflineManager();

    return Card(
      margin: const EdgeInsets.all(16),
      child: isOnlineAsync.when(
        data: (isOnline) {
          return syncQueueStatus.when(
            data: (items) {
              final lastSyncTime = _getLastSyncTime();

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOnline ? Icons.cloud_done : Icons.cloud_off,
                          color: isOnline ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text('Last synced: $lastSyncTime'),
                    const SizedBox(height: 8),
                    Text('Pending sync items: ${items.length}'),
                    if (isOnline && items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await offlineManager.manualSync();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          }
                        },
                        child: const Text('Sync Now'),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading sync status'),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Error checking connection status'),
        ),
      ),
    );
  }

  String _getLastSyncTime() {
    try {
      final offlineManager = OfflineManager();
      final status = offlineManager.statusStream.first as OfflineStatus?;

      if (status == null || status.lastSyncTimestamp == null) {
        return 'Never';
      }

      final now = DateTime.now();
      final difference = now.difference(status.lastSyncTimestamp!);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} hours ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
