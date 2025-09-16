import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_data_service.dart';
import '../models/sync_models.dart';

final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(FirebaseDataService());
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

  SyncNotifier(this._dataService) : super(SyncState());

  Future<void> syncAll() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null);

    try {
      // Sync user preferences
      final prefs = await _dataService.getUserPreferences();
      if (prefs != null) {
        // Apply preferences to local storage
        // TODO: Implement this based on your preferences structure
      }

      // Sync bible marks
      final marks = await _dataService.getBibleMarks();
      // TODO: Merge with local storage
      print('Retrieved ${marks.length} bible marks');

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
