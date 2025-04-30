// lib/widgets/offline_content_placeholder.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// A widget to display when content is not available offline
class OfflineContentPlaceholder extends ConsumerWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final bool showNetworkStatus;

  const OfflineContentPlaceholder({
    super.key,
    this.title = 'Content Not Available Offline',
    this.message =
        'This content requires an internet connection to view. Please connect to the internet and try again.',
    this.icon = Icons.cloud_off,
    this.onActionPressed,
    this.actionLabel = 'Try Again',
    this.showNetworkStatus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(connectivityProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            if (showNetworkStatus)
              isOnlineAsync.when(
                data: (isOnline) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isOnline ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 16,
                        color: isOnline
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color: isOnline
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Connection status unknown'),
              ),
            const SizedBox(height: 24),
            if (onActionPressed != null && actionLabel != null)
              ElevatedButton(
                onPressed: onActionPressed,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

/// A more compact version of the offline content placeholder
class CompactOfflineContentPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CompactOfflineContentPlaceholder({
    super.key,
    this.message = 'Content not available offline',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// A specialized placeholder for Bible content
class BibleOfflineContentPlaceholder extends StatelessWidget {
  final String bookName;
  final int chapterId;
  final VoidCallback? onDownloadPressed;

  const BibleOfflineContentPlaceholder({
    super.key,
    required this.bookName,
    required this.chapterId,
    this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            Text(
              '$bookName $chapterId',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This chapter is not available offline.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (onDownloadPressed != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download for Offline Use'),
                onPressed: onDownloadPressed,
              ),
          ],
        ),
      ),
    );
  }
}

/// A specialized placeholder for devotional content
class DevotionalOfflineContentPlaceholder extends StatelessWidget {
  final String? title;
  final VoidCallback? onDownloadPressed;

  const DevotionalOfflineContentPlaceholder({
    super.key,
    this.title,
    this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_stories,
              size: 64,
              color: Colors.indigo,
            ),
            const SizedBox(height: 24),
            if (title != null)
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            const Text(
              'This devotional is not available offline.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (onDownloadPressed != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download for Offline Use'),
                onPressed: onDownloadPressed,
              ),
          ],
        ),
      ),
    );
  }
}
