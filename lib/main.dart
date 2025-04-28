import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Add this import

import 'router.dart';
import 'config/theme.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'models/bible_model.dart'; // Ensure this model is updated with Hive annotations

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive for Flutter
    await Hive.initFlutter();

    // Initialize local storage first
    await LocalStorageService.initialize();

    // Register Hive adapters
    _registerHiveAdapters();

    // Initialize connectivity service
    final connectivityService = ConnectivityService();

    // Initialize sync service
    final syncService = SyncService();

    // Listen for connectivity changes and trigger sync
    connectivityService.connectionStatusStream.listen((isOnline) {
      if (isOnline) {
        // Perform sync when online
        syncService.performPeriodicSync();
      }
    });

    // Start periodic background sync
    syncService.startBackgroundSync();

    // Load environment variables
    await dotenv.load();

    // Initialize date formatting
    await initializeDateFormatting('ms', null);

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    runApp(const ProviderScope(child: MyApp()));
  } catch (e) {
    // Centralized error handling
    _handleInitializationError(e);
  }
}

// Register Hive type adapters
void _registerHiveAdapters() {
  // Ensure these adapters are generated
  // Run: flutter pub run build_runner build
  Hive.registerAdapter(BibleBookAdapter());
  Hive.registerAdapter(BibleVerseAdapter());
  Hive.registerAdapter(BibleVersionAdapter());
}

// Centralized error handling for initialization
void _handleInitializationError(Object error) {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                'Initialization Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Error: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => main(), // Retry initialization
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Alkitab 2.0',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Update error widget builder
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        };
        return child!;
      },
    );
  }
}
