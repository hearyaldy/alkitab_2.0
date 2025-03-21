import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alkitab_2_0/services/local_storage_service.dart';
import 'package:alkitab_2_0/services/supabase_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load();
  
  // Initialize services
  await SupabaseService.initialize();
  await LocalStorageService.initialize();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}