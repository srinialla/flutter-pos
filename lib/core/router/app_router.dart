import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/platform_utils.dart';
import '../../providers/auth_provider.dart';

// Import screens
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/products/add_edit_product_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/sales/sales_history_screen.dart';
import '../../screens/scanner/scanner_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';

class AppRouter {
  static GoRouter get router => _router;

  static final _router = GoRouter(
    initialLocation: '/splash',
    redirect: _handleRedirect,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main App Routes (Protected)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/products',
            name: 'products',
            builder: (context, state) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: '/add',
                name: 'add-product',
                builder: (context, state) => const AddEditProductScreen(),
              ),
              GoRoute(
                path: '/edit/:id',
                name: 'edit-product',
                builder: (context, state) {
                  final productId = state.pathParameters['id']!;
                  return AddEditProductScreen(productId: productId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/sales',
            name: 'sales',
            builder: (context, state) => const SalesScreen(),
          ),
          GoRoute(
            path: '/sales-history',
            name: 'sales-history',
            builder: (context, state) => const SalesHistoryScreen(),
          ),
          GoRoute(
            path: '/scanner',
            name: 'scanner',
            builder: (context, state) => const ScannerScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );

  static String? _handleRedirect(BuildContext context, GoRouterState state) {
    final authService = AuthService.instance;
    final isLoggedIn = authService.isLoggedIn;
    final currentLocation = state.uri.toString();

    // Handle splash screen
    if (currentLocation == '/splash') {
      return null; // Allow splash screen to handle navigation
    }

    // Auth routes - redirect to dashboard if already logged in
    final authRoutes = ['/login', '/signup', '/forgot-password'];
    if (authRoutes.contains(currentLocation) && isLoggedIn) {
      return '/dashboard';
    }

    // Protected routes - redirect to login if not logged in
    final protectedRoutes = ['/dashboard', '/products', '/sales', '/sales-history', '/scanner', '/settings'];
    if (protectedRoutes.any((route) => currentLocation.startsWith(route)) && !isLoggedIn) {
      return '/login';
    }

    return null; // No redirect needed
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.shouldUseNavDrawer(context)) {
      return ResponsiveScaffold(child: child);
    } else if (PlatformUtils.shouldUseNavigationRail(context)) {
      return NavigationRailLayout(child: child);
    } else {
      return Scaffold(
        body: child,
        bottomNavigationBar: const BottomNavBar(),
      );
    }
  }
}

// Navigation destinations
final List<NavigationItem> navigationItems = [
  NavigationItem(
    icon: Icons.dashboard,
    label: 'Dashboard',
    route: 'dashboard',
  ),
  NavigationItem(
    icon: Icons.inventory,
    label: 'Products',
    route: 'products',
  ),
  NavigationItem(
    icon: Icons.shopping_cart,
    label: 'Sales',
    route: 'sales',
  ),
  NavigationItem(
    icon: Icons.qr_code_scanner,
    label: 'Scanner',
    route: 'scanner',
  ),
  NavigationItem(
    icon: Icons.settings,
    label: 'Settings',
    route: 'settings',
  ),
];

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    int selectedIndex = 0;
    for (int i = 0; i < navigationItems.length; i++) {
      if (currentLocation.startsWith('/${navigationItems[i].route}')) {
        selectedIndex = i;
        break;
      }
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        context.goNamed(navigationItems[index].route);
      },
      destinations: navigationItems.map((item) => NavigationDestination(
        icon: Icon(item.icon),
        label: item.label,
      )).toList(),
    );
  }
}

class NavigationRailLayout extends StatelessWidget {
  final Widget child;

  const NavigationRailLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    int selectedIndex = 0;
    for (int i = 0; i < navigationItems.length; i++) {
      if (currentLocation.startsWith('/${navigationItems[i].route}')) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              context.goNamed(navigationItems[index].route);
            },
            labelType: NavigationRailLabelType.all,
            destinations: navigationItems.map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            )).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class ResponsiveScaffold extends StatelessWidget {
  final Widget child;

  const ResponsiveScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    int selectedIndex = 0;
    for (int i = 0; i < navigationItems.length; i++) {
      if (currentLocation.startsWith('/${navigationItems[i].route}')) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationDrawer(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              context.goNamed(navigationItems[index].route);
            },
            children: [
              const DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.point_of_sale, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'POS App',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ...navigationItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                );
              }),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}