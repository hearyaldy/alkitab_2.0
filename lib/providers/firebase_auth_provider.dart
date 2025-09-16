import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/firebase_data_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final firebaseDataServiceProvider = Provider<FirebaseDataService>((ref) {
  return FirebaseDataService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(firebaseServiceProvider).authStateChanges;
});

final userProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<User?> {
  final Ref _ref;
  late final FirebaseService _firebaseService;
  late final FirebaseDataService _dataService;

  UserNotifier(this._ref) : super(null) {
    _firebaseService = _ref.read(firebaseServiceProvider);
    _dataService = _ref.read(firebaseDataServiceProvider);
    state = _firebaseService.currentUser;
  }

  Future<bool> signInWithGoogle() async {
    final credential = await _firebaseService.signInWithGoogle();
    if (credential != null) {
      state = credential.user;
      return true;
    }
    return false;
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    final credential =
        await _firebaseService.signInWithEmailPassword(email, password);
    if (credential != null) {
      state = credential.user;
      return true;
    }
    return false;
  }

  Future<bool> signUpWithEmailPassword(String email, String password) async {
    final credential =
        await _firebaseService.signUpWithEmailPassword(email, password);
    if (credential != null) {
      state = credential.user;
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    state = null;
  }

  Future<DateTime?> getLastSyncTimestamp() {
    return _firebaseService.getLastSyncTimestamp();
  }

  Future<void> deleteAccount() async {
    if (state == null) return;
    await _dataService.deleteUserData();
    await state?.delete();
    await signOut();
  }
}
