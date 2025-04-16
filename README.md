# Alkitab 2.0

A fully cross-platform (Android, iOS, Web, Desktop) Bible application built using Flutter. This app supports scripture reading, bookmarking, devotionals, profiles, and integration with Supabase for backend services.

## ✨ Features
- Read the full Bible with structured navigation
- Highlight and bookmark verses
- Add personal notes to any verse
- User authentication via Supabase
- Daily devotional reading support
- Save devotional notes to Supabase
- Reading plan tracking
- Offline access and sync support
- Multi-platform (Android, iOS, Web, Desktop)
- Custom theming and font support
- Read the full Bible with structured navigation
- Highlight and bookmark verses
- Add personal notes to any verse
- User authentication via Supabase
- Daily devotional reading support
- Reading plan tracking
- Offline access and sync support
- Multi-platform (Android, iOS, Web, Desktop)
- Custom theming and font support

## 📁 Project Structure

```
lib/
├── main.dart              # Entry point of the application
├── app.dart               # Root widget and app configuration
├── router.dart            # Centralized route management
│
├── config/                # Global app configurations
│   ├── constants.dart     # Static constants (colors, keys, etc.)
│   └── theme.dart         # App-wide themes and styles
│
├── models/                # Data models (structure of data used)
│   ├── bible_model.dart
│   ├── bookmark_model.dart
│   ├── user_model.dart
│   └── ...
│
├── services/              # Handles API and business logic
│   ├── supabase_service.dart  # Authentication & data sync with Supabase
│   ├── auth_service.dart
│   └── ...
│
├── providers/             # State management using Provider
│   ├── auth_provider.dart
│   ├── settings_provider.dart
│   └── ...
│
├── screens/               # Application UI split by features
│   ├── auth/              # Login, Register, Reset Password
│   ├── bible/             # Bible reader and verse views
│   ├── devotional/        # Devotional reading and note-taking
│   ├── profile/           # Profile and editing
│   ├── settings/          # Settings and preferences
│   ├── tabs/              # Tab navigation views
│   └── ...               # Application UI split by features
│   ├── auth/              # Login, Register, Reset Password
│   ├── bible/             # Bible reader and verse views
│   ├── profile/           # Profile and editing
│   ├── settings/          # Settings and preferences
│   ├── tabs/              # Tab navigation views
│   └── ...
│
├── widgets/               # Reusable UI components
│   └── collapsible_header.dart
│
├── utils/                 # Utility functions and helpers
│   ├── bible_parser.dart
│   ├── offline_manager.dart
│   └── notification_helper.dart
```

## 📦 Assets
```
assets/
├── fonts/                 # Custom fonts (e.g., Roboto)
├── images/                # Header and decorative images
```

## 🧪 Testing
```
test/
├── widget_test.dart       # Default widget test
```

## 💻 Platform Support
- Android
- iOS
- Web
- Linux
- macOS
- Windows

## 🔧 Configuration Files
- `pubspec.yaml`: Project dependencies
- `.metadata`, `analysis_options.yaml`: Dart analysis config
- Platform-specific folders: `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/`

## 🚀 Getting Started
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install)
2. Run `flutter pub get`
3. Use `flutter run` to start the app on your preferred platform

---

Built with ❤️ using Flutter and Supabase.

> This structure enables clean separation of concerns and scalable feature growth.

