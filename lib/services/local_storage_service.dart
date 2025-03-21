import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';

class LocalStorageService {
  static Future<void> initialize() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    
    // Register Hive adapters here later
    // Hive.registerAdapter(BibleBookAdapter());
    
    // Open boxes
    await Hive.openBox(AppConstants.settingsBoxName);
    await Hive.openBox(AppConstants.bibleContentBoxName);
    await Hive.openBox(AppConstants.userBoxName);
  }
  
  static Box getSettingsBox() {
    return Hive.box(AppConstants.settingsBoxName);
  }
  
  static Box getBibleContentBox() {
    return Hive.box(AppConstants.bibleContentBoxName);
  }
  
  static Box getUserBox() {
    return Hive.box(AppConstants.userBoxName);
  }
  
  static Future<void> saveValue(String boxName, String key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }
  
  static dynamic getValue(String boxName, String key, {dynamic defaultValue}) {
    final box = Hive.box(boxName);
    return box.get(key, defaultValue: defaultValue);
  }
  
  static Future<void> deleteValue(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }
  
  static Future<void> clearBox(String boxName) async {
    final box = Hive.box(boxName);
    await box.clear();
  }
}