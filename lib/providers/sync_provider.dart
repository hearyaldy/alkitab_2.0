import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_data_service.dart';
import '../services/progress_tracking_service.dart';
import '../models/sync_models.dart';

final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(FirebaseDataService(), ProgressTrackingService());
});

class SyncState {
  final bool isSyncing;
  final DateTime? lastSynced;
  final String? error;

  SyncState({
    this.isSyncing = false,
    this.lastSynced,
    this.error,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSynced,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSynced: lastSynced ?? this.lastSynced,
      error: error ?? this.error,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final FirebaseDataService _dataService;
  final ProgressTrackingService _progressService;

  SyncNotifier(this._dataService, this._progressService) : super(SyncState());

  Future<void> syncAll() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null);

    try {
      // Pull reading progress (streak, totals, weekly goal) from the cloud
      // and merge it into local storage. Bookmarks and highlights already
      // sync live via Firestore streams, so they don't need a manual pull.
      await _progressService.syncProgressFromCloud();

      // Update sync timestamp
      state = state.copyWith(
        isSyncing: false,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  Future<void> pushLocalChanges({
    UserPreferences? preferences,
    List<UserBibleMark>? marks,
  }) async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null);

    try {
      if (preferences != null) {
        await _dataService.syncUserPreferences(preferences);
      }

      if (marks != null) {
        for (var mark in marks) {
          await _dataService.syncBibleMark(mark);
        }
      }

      state = state.copyWith(
        isSyncing: false,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }
}
