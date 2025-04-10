import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tabs/home_tab.dart';
import 'screens/tabs/bible_tab.dart';
import 'screens/tabs/devotional_tab.dart';
import 'screens/tabs/profile_tab.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/bible/bible_reader_screen.dart';
import 'screens/bookmarks/bookmarks_screen.dart'; // Import your bookmarks screen

final router = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn =
        state.fullPath == '/login' || state.fullPath == '/register';
    if (session == null && !isLoggingIn) return '/login';
    if (session != null && isLoggingIn) return '/home';
    return null;
  },
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
    // Main route for tab-based navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(
          tabIndex: navigationShell.currentIndex,
          shell: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bible',
              builder: (context, state) => const BibleTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/devotional',
              builder: (context, state) => const DevotionalTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileTab(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/bible-reader',
      builder: (context, state) {
        final bookId = state.uri.queryParameters['bookId'];
        final chapterId =
            int.tryParse(state.uri.queryParameters['chapterId'] ?? '1') ?? 1;
        return BibleReaderScreen(bookId: bookId, chapterId: chapterId);
      },
    ),
    // New route for the bookmarks screen.
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
  ],
);
