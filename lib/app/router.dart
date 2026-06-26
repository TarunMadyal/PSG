import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/domain/capability.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/setup_screen.dart';
import '../features/billing/presentation/billing_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/widgets/app_logo.dart';
import 'app_shell.dart';
import 'nav_destination.dart';

/// The app router, rebuilt with auth state so redirects gate the whole app.
///
/// Routing rules:
/// - loading        → splash
/// - no accounts    → first-run setup
/// - signed out     → login
/// - signed in      → app shell; deep links to a route the user lacks the
///   capability for are bounced to Billing (defence-in-depth with the UI/RLS).
final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod auth changes into a Listenable so go_router re-evaluates
  // redirects whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      const gates = {'/', '/login', '/setup'};

      switch (auth) {
        case AuthLoading():
          return loc == '/' ? null : '/';
        case AuthNeedsSetup():
          return loc == '/setup' ? null : '/setup';
        case AuthUnauthenticated():
          return loc == '/login' ? null : '/login';
        case AuthAuthenticated(:final user):
          if (gates.contains(loc)) return '/billing';
          final caps = capabilitiesFor(user.role);
          for (final d in kPosDestinations) {
            if (loc.startsWith(d.path) &&
                !caps.contains(d.requiredCapability)) {
              return '/billing';
            }
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _branch('/billing', const BillingScreen()),
          _branch('/products', const ProductsScreen()),
          _branch('/inventory', const InventoryScreen()),
          _branch('/customers', const CustomersScreen()),
          _branch('/reports', const ReportsScreen()),
          _branch('/settings', const SettingsScreen()),
        ],
      ),
    ],
  );
});

StatefulShellBranch _branch(String path, Widget child) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (context, state) => child)],
    );

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 72),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
