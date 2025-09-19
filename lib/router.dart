import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tabs/home_tab.dart' as home_tab;
import 'screens/tabs/bible_tab.dart';
import 'screens/tabs/devotional_tab.dart';
import 'screens/tabs/profile_tab.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/devotional/devotional_search_screen.dart';
import 'screens/progress/progress_dashboard_screen.dart';
import 'screens/analytics/analytics_dashboard_screen.dart';
import 'screens/bible/bible_reader_screen.dart';
import 'screens/bookmarks/bookmarks_screen.dart';
import 'screens/admin/data_migration_screen.dart';
import 'screens/admin/devotional_admin_screen.dart';
import 'screens/admin/enhanced_devotional_admin_screen.dart';
import 'screens/admin/user_admin_screen.dart';

final router = GoRouter(
  initialLocation: '/home',
  // Allow access to app without authentication, but track auth state
  redirect: (context, state) {
    final isAuthenticated = AuthService.currentUser != null;
    final isGoingToAuth = state.matchedLocation == '/login' ||
                         state.matchedLocation == '/register' ||
                         state.matchedLocation == '/reset-password';

    // If user is authenticated and trying to go to auth pages, redirect to home
    if (isAuthenticated && isGoingToAuth) {
      return '/home';
    }

    // Allow all other navigation (app works without auth)
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
              builder: (context, state) => const home_tab.HomeTab(),
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
      path: '/notification-settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/devotional-search',
      builder: (context, state) => const DevotionalSearchScreen(),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressDashboardScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsDashboardScreen(),
    ),
    GoRoute(
      path: '/data-migration',
      builder: (context, state) => const DataMigrationScreen(),
    ),
    GoRoute(
      path: '/bible-reader',
      builder: (context, state) {
        final bookId = state.uri.queryParameters['bookId'];
        final chapterId =
            int.tryParse(state.uri.queryParameters['chapterId'] ?? '1') ?? 1;
        final scrollToVerse =
            int.tryParse(state.uri.queryParameters['scrollToVerse'] ?? '');
        return BibleReaderScreen(
          bookId: bookId,
          chapterId: chapterId,
          scrollToVerse: scrollToVerse,
        );
      },
    ),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: '/admin/devotionals',
      builder: (context, state) => const DevotionalAdminScreen(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UserAdminScreen(),
    ),
    GoRoute(
      path: '/admin/enhanced-devotionals',
      builder: (context, state) => const EnhancedDevotionalAdminScreen(),
    ),
  ],
);
