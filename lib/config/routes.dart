import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/home_screen.dart';
import '../screens/bible/bible_reader_screen.dart';
import '../screens/settings/settings_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/bible-reader',
        builder: (context, state) {
          // Use state.pathParameters or state.extra instead of queryParameters
          // depending on your go_router version
          final Map<String, dynamic> params = state.extra as Map<String, dynamic>? ?? {};
          final String? bookId = params['bookId'] as String?;
          final int chapterId = params['chapterId'] as int? ?? 1;
          
          return BibleReaderScreen(bookId: bookId, chapterId: chapterId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}