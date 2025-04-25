import 'package:connectivity_plus/connectivity_plus.dart';

class SyncHelper {
  // Check internet connectivity
  static Future<bool> isConnected() async {
    final connectivity = Connectivity();
    var result = await connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
  }

  // Retry mechanism for sync operations
  static Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) rethrow;
        await Future.delayed(delay);
      }
    }
    throw Exception('Operation failed after $maxAttempts attempts');
  }
}
