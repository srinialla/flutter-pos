import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
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
    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    int selectedIndex = 0;
    if (currentLocation.startsWith('/products')) {
      selectedIndex = 1;
    } else if (currentLocation.startsWith('/sales')) {
      selectedIndex = 2;
    } else if (currentLocation.startsWith('/scanner')) {
      selectedIndex = 3;
    } else if (currentLocation.startsWith('/settings')) {
      selectedIndex = 4;
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.goNamed('dashboard');
            break;
          case 1:
            context.goNamed('products');
            break;
          case 2:
            context.goNamed('sales');
            break;
          case 3:
            context.goNamed('scanner');
            break;
          case 4:
            context.goNamed('settings');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory),
          label: 'Products',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart),
          label: 'Sales',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Scanner',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}