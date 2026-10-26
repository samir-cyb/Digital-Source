import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/store.dart';
import 'core/theme.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/member_home.dart';
import 'screens/today.dart';
import 'screens/projects.dart';
import 'screens/team.dart';
import 'screens/operations.dart';
import 'screens/planning.dart';
import 'ui/shell.dart';
import 'ui/components.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DigitalSourceApp());
}

class DigitalSourceApp extends StatefulWidget {
  final AppStore? store;
  const DigitalSourceApp({super.key, this.store});
  @override
  State<DigitalSourceApp> createState() => _DigitalSourceAppState();
}

class _DigitalSourceAppState extends State<DigitalSourceApp> {
  Timer? refreshTimer;
  late final AppStore store = widget.store ?? AppStore();
  late final GoRouter router = GoRouter(
    initialLocation: '/today',
    refreshListenable: store,
    redirect: (context, state) {
      final login = state.matchedLocation == '/login';
      final signup = state.matchedLocation == '/signup';
      final authPage = login || signup;
      final loading = state.matchedLocation == '/loading';
      final requested = state.uri.queryParameters['from'] ?? '/today';
      final parsed = Uri.tryParse(requested);
      final safe =
          parsed != null &&
          !parsed.hasScheme &&
          parsed.host.isEmpty &&
          RegExp(
            r'^/(today|manager|my-work|projects|team|planning|sourcing|finance|reports|inbox|settings)(/[^?]*)?$',
          ).hasMatch(parsed.path);
      final destination =
          safe && store.canAccess(parsed.path) && parsed.path != '/today'
          ? requested
          : store.homeRoute;
      if (store.booting) {
        if (loading || authPage) return null;
        final target = login ? destination : state.uri.toString();
        return '/loading?from=${Uri.encodeComponent(target)}';
      }
      if (store.user == null) {
        if (authPage) return null;
        final target = loading ? destination : state.uri.toString();
        return '/login?from=${Uri.encodeComponent(target)}';
      }
      if (authPage) return store.homeRoute;
      if (loading) return destination;
      if (state.matchedLocation == '/today' ||
          !store.canAccess(state.uri.path)) {
        return store.homeRoute;
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: EmptyState(
        'This page is not available',
        'Return to your workspace.',
        action: FilledButton(
          onPressed: () => context.go('/today'),
          child: const Text('Go to Today'),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, state) => LoginScreen(store)),
      GoRoute(path: '/signup', builder: (_, state) => SignupScreen(store)),
      ShellRoute(
        builder: (context, state, child) => ListenableBuilder(
          listenable: store,
          builder: (context, _) => StudioShell(store: store, child: child),
        ),
        routes: [
          GoRoute(path: '/today', redirect: (_, state) => store.homeRoute),
          GoRoute(
            path: '/my-work',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => MemberDashboardScreen(store),
            ),
          ),
          GoRoute(
            path: '/manager',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => TodayScreen(store),
            ),
          ),
          GoRoute(
            path: '/projects',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => ProjectsScreen(store),
            ),
          ),
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) =>
                  ProjectDetailScreen(store, state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/team',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => TeamScreen(store),
            ),
          ),
          GoRoute(
            path: '/team/:id',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) =>
                  ProfileScreen(store, state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/planning',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => PlanningScreen(store),
            ),
          ),
          GoRoute(
            path: '/sourcing',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => SourcingScreen(store),
            ),
          ),
          GoRoute(
            path: '/finance',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => FinanceScreen(store),
            ),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => ReportsScreen(store),
            ),
          ),
          GoRoute(
            path: '/inbox',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => InboxScreen(store),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, state) => ListenableBuilder(
              listenable: store,
              builder: (_, child) => SettingsScreen(store),
            ),
          ),
        ],
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    if (widget.store == null) {
      store.restore();
      refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (store.user != null && !store.loading) {
          store.reload().catchError((_) {});
        }
      });
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    router.dispose();
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp.router(
      title: 'Digital Source — Studio workspace',
      debugShowCheckedModeBanner: false,
      theme: studioTheme(Brightness.light),
      darkTheme: studioTheme(Brightness.dark),
      themeMode: store.themeMode,
      routerConfig: router,
    ),
  );
}
