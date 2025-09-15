// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'router.dart';
import 'config/theme.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'models/bible_model.dart';
import 'utils/offline_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚨 TEMPORARY: Clear Hive data immediately during development
  await Hive.initFlutter();

  try {
    await LocalStorageService.initialize().timeout(const Duration(seconds: 10));
    await OfflineManager().initialize().timeout(const Duration(seconds: 10)); // ✅ Important!

    _registerHiveAdapters();

    final connectivityService = ConnectivityService();
    final syncService = SyncService();

    connectivityService.connectionStatusStream.listen((isOnline) {
      if (isOnline) {
        syncService.performPeriodicSync();
      }
    });

    syncService.startBackgroundSync();

    await dotenv.load();
    await initializeDateFormatting('ms', null);

    // Only initialize Supabase if valid credentials are provided
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl != null &&
        supabaseKey != null &&
        supabaseUrl != 'your_supabase_url_here' &&
        supabaseKey != 'your_supabase_anon_key_here') {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
    } else {
      print('Warning: Supabase credentials not configured. Running in offline mode.');
    }

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
