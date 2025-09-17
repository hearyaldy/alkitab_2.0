// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'config/theme.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage_service.dart';
import 'services/mock_data_service.dart';
import 'models/bible_model.dart';
import 'utils/offline_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check - Temporarily disabled to fix API issues
  // await FirebaseAppCheck.instance.activate(
  //   // For Android: use the debug provider during development
  //   androidProvider: AndroidProvider.debug,
  //   // For iOS: use the debug provider during development
  //   appleProvider: AppleProvider.debug,
  // );

  // Initialize Hive
  await Hive.initFlutter();

  try {
    // Simplified initialization for debugging
    _registerHiveAdapters();

    // Try to initialize services but don't fail if they timeout
    try {
      await LocalStorageService.initialize()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('LocalStorageService initialization failed: $e');
    }

    try {
      await OfflineManager().initialize().timeout(const Duration(seconds: 5));
    } catch (e) {
      print('OfflineManager initialization failed: $e');
    }

    await dotenv.load();
    await initializeDateFormatting('ms', null);

    // Initialize mock data service for offline development
    await MockDataService.initialize();
    print('Mock data service initialized for offline development.');

    runApp(const ProviderScope(child: MyApp()));
  } catch (e) {
    _handleInitializationError(e);
  }
}

void _registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(BibleBookAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(BibleVerseAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(BibleVersionAdapter());
  }
}

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
                onPressed: () => main(),
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
