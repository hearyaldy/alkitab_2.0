import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal() {
    // Initialize connectivity monitoring
    _connectivity.onConnectivityChanged.listen((results) {
      // Handle multiple results by checking for any online connectivity
      final isOnline =
          results.any((result) => result != ConnectivityResult.none);
      _handleConnectivityChange(isOnline);
    });

    // Check initial state
    checkConnection();
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  Future<void> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();

      // Check if any result indicates connectivity
      final isOnline =
          results.any((result) => result != ConnectivityResult.none);

      _handleConnectivityChange(isOnline);
    } catch (e) {
      debugPrint('ConnectivityService: Error checking connection - $e');
      _isOnline = false;
      _connectionStatusController.add(false);
    }
  }

  void _handleConnectivityChange(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _connectionStatusController.add(_isOnline);
      debugPrint('ConnectivityService: Connection status - $_isOnline');
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
