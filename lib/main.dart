import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/firebase_config.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/barcode_service.dart';
import 'core/services/security_service.dart';
import 'core/services/backup_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/refund_service.dart';
import 'core/services/team_sync_service.dart';
import 'core/services/inventory_alerts_service.dart';
import 'core/services/export_service.dart';
import 'core/services/printer_service.dart';
import 'core/services/notification_service.dart';
import 'core/utils/platform_utils.dart';

// Conditional imports for desktop
import 'package:window_manager/window_manager.dart' if (dart.library.html) 'dart:html';
import 'package:desktop_window/desktop_window.dart' if (dart.library.html) 'dart:html';

import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';

import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Platform-specific initialization
  await _initializePlatform();
  
  // Initialize Firebase
  await FirebaseInitializer.initialize();
  
  // Initialize security service first
  await SecurityService.instance.initialize();
  
  // Initialize local storage
  await LocalStorageService.instance.init();
  
  // Initialize analytics and monitoring
  await AnalyticsService.instance.initialize();
  
  // Initialize notification service
  await NotificationService.instance.initialize();
  
  // Initialize team sync service
  await TeamSyncService.instance.initialize();
  
  // Initialize refund service
  await RefundService.instance.initialize();
  
  // Initialize printer service
  await PrinterService.instance.initialize();
  
  // Initialize export service
  await ExportService.instance.initialize();
  
  // Initialize inventory alerts service
  await InventoryAlertsService.instance.initialize();
  
  // Initialize barcode service (mobile only)
  if (PlatformUtils.supportsBarcodeScanning) {
    await BarcodeService.instance.initialize();
  }
  
  // Schedule auto backup
  BackupService.instance.scheduleAutoBackup();
  
  runApp(const POSApp());
}

Future<void> _initializePlatform() async {
  if (PlatformUtils.isDesktop) {
    // Initialize desktop window
    await windowManager.ensureInitialized();
    
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'POS Flutter App',
            debugShowCheckedModeBanner: false,
            
            // Theme Configuration
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.light,
              ),
              textTheme: GoogleFonts.robotoTextTheme(),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardTheme(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.dark,
              ),
              textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardTheme(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}