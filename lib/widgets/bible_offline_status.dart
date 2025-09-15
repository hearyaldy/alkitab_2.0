// lib/widgets/bible_offline_status.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';
import '../utils/offline_manager.dart';
import '../constants/bible_data.dart';

class BibleOfflineStatus extends ConsumerWidget {
  final String bookId;
  final int chapterId;
  final String version;
  final VoidCallback? onDownload;

  const BibleOfflineStatus({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.version,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(connectivityProvider);
    final offlineManager = OfflineManager();

    return FutureBuilder<bool>(
      future: offlineManager.isContentAvailableOffline(
        'bible',
        '${version}_${bookId}_$chapterId',
      ),
      builder: (context, snapshot) {
        final isAvailableOffline = snapshot.data ?? false;

        return isOnlineAsync.when(
          data: (isOnline) {
            if (isAvailableOffline) {
              // Content is available offline, show small indicator
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin,
                        size: 14, color: Colors.green.shade800),
                    const SizedBox(width: 4),
                    Text(
                      'Available Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              );
            } else if (!isOnline) {
              // Not available and offline - show warning
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 18, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${getBookNameById(bookId)} $chapterId not available offline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You\'re currently offline and this content has not been saved for offline use.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              );
            } else if (onDownload != null) {
              // Online but not available offline - show download option
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_download,
                        size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onDownload,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Save for offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink(); // Online and no download option
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Widget to show a download progress indicator for Bible content
class BibleDownloadProgress extends StatelessWidget {
  final String bookId;
  final int chapterId;
  final double progress;
  final VoidCallback? onCancel;

  const BibleDownloadProgress({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading ${getBookNameById(bookId)} $chapterId',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onCancel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey.shade600,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
