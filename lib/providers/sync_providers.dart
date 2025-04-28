// lib/providers/sync_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/connectivity_service.dart';
import '../services/sync_queue_processor.dart';

// Connectivity Service Provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Sync Queue Processor Provider
final syncQueueProcessorProvider = Provider<SyncQueueProcessor>((ref) {
  return SyncQueueProcessor();
});

// Stream provider for sync queue status
final syncQueueStatusProvider = StreamProvider<List<dynamic>>((ref) async* {
  while (true) {
    try {
      final box = await Hive.openBox('sync_queue');

      yield box.values.toList();

      await Future.delayed(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Error in sync queue status provider: $e');
      yield [];
    }
  }
});

// Sync Manager for centralized sync operations
class SyncManager {
  final SyncQueueProcessor _syncQueueProcessor;
  final ConnectivityService _connectivityService;

  SyncManager(this._syncQueueProcessor, this._connectivityService) {
    // Optionally you can start periodic sync here manually if you want
    // _syncQueueProcessor.startBackgroundSync();
  }

  Future<void> triggerSync() async {
    if (_connectivityService.isOnline) {
      await _syncQueueProcessor.processQueue();
    }
  }

  Future<void> addToSyncQueue({
    required SyncOperationType type,
    required Map<String, dynamic> data,
  }) async {
    await _syncQueueProcessor.addToQueue(type: type, data: data);
  }
}

// Provider for SyncManager
final syncManagerProvider = Provider<SyncManager>((ref) {
  final syncQueueProcessor = ref.watch(syncQueueProcessorProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return SyncManager(syncQueueProcessor, connectivityService);
});

// Sync Status Widget
class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncQueueStatusProvider);

    return syncStatus.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          color: Colors.yellow[100],
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.sync, color: Colors.orange),
              const SizedBox(width: 8),
              Text('${items.length} items pending sync'),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Container(
        color: Colors.red[100],
        padding: const EdgeInsets.all(8),
        child: Text('Sync Error: $error'),
      ),
    );
  }
}
