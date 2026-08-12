import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:baqati/screens/app_shell.dart';
import 'package:baqati/screens/history_screen.dart';
import 'package:baqati/screens/home_screen.dart';
import 'package:baqati/screens/manual_alert_screen.dart';
import 'package:baqati/screens/onboarding_screen.dart';
import 'package:baqati/screens/package_details_screen.dart';
import 'package:baqati/screens/settings_screen.dart';
import 'package:baqati/services/settings_service.dart';

abstract final class Routes {
  static const String home = '/';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String packageDetails = '/package-details';
  static const String manualAlert = '/manual-alert';
}

/// Builds the app's router.
///
/// Onboarding is enforced by a [GoRouter.redirect] rather than by choosing a
/// start destination. The Kotlin computed its start destination from two
/// DataStore flows read asynchronously with `initial = false`, which could send
/// an already-onboarded user to onboarding on the first frame — and Compose
/// Navigation ignores a start destination that changes afterwards. A redirect
/// re-evaluates on every navigation and reacts to [settings] changing.
GoRouter buildRouter(SettingsService settings) {
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: Routes.home,
    navigatorKey: rootNavigatorKey,
    refreshListenable: settings,
    redirect: (BuildContext context, GoRouterState state) {
      final bool goingToOnboarding = state.matchedLocation == Routes.onboarding;
      if (!settings.isOnboarded) {
        return goingToOnboarding ? null : Routes.onboarding;
      }
      return goingToOnboarding ? Routes.home : null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.packageDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const PackageDetailsScreen(),
      ),
      GoRoute(
        path: Routes.manualAlert,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ManualAlertScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.history,
                builder: (BuildContext context, GoRouterState state) =>
                    const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.settings,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
