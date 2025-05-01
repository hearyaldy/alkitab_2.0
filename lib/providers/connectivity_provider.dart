import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

// Provider for the ConnectivityService instance
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Stream provider that exposes the online/offline status
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.connectionStatusStream;
});

// Simple provider to get the current online status synchronously
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.isOnline;
});