import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  
  // Feature availability
  static bool get supportsBarcodeScanning => isMobile;
  static bool get supportsCamera => isMobile;
  static bool get supportsFileSystem => !isWeb;
  static bool get supportsNativeSharing => isMobile;
  static bool get supportsWindowManagement => isDesktop;
  
  // Screen size categories
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }
  
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }
  
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }
  
  // Layout helpers
  static bool shouldUseNavDrawer(BuildContext context) {
    return isLargeScreen(context) || isDesktop;
  }
  
  static bool shouldUseBottomNav(BuildContext context) {
    return isSmallScreen(context) && isMobile;
  }
  
  static bool shouldUseNavigationRail(BuildContext context) {
    return isMediumScreen(context) || (isDesktop && !isLargeScreen(context));
  }
  
  // Platform-specific UI constants
  static double getAppBarHeight() {
    if (isWeb || isDesktop) return 64.0;
    return 56.0;
  }
  
  static EdgeInsets getDefaultPadding() {
    if (isDesktop || isWeb) return const EdgeInsets.all(24.0);
    return const EdgeInsets.all(16.0);
  }
  
  static double getCardElevation() {
    if (isWeb) return 1.0;
    if (isDesktop) return 2.0;
    return 4.0;
  }
  
  // Input methods
  static bool get supportsKeyboardShortcuts => isDesktop || isWeb;
  static bool get supportsTouchInput => isMobile || isWeb;
  static bool get supportsMouseInput => isDesktop || isWeb;
  
  // Storage capabilities
  static String get preferredStorageLocation {
    if (isWeb) return 'IndexedDB';
    if (isMobile) return 'App Documents';
    return 'User Documents';
  }
  
  // Network capabilities
  static bool get supportsOfflineMode => !isWeb;
  static bool get requiresInternetConnection => isWeb;
  
  // Platform-specific behaviors
  static bool get showWindowControls => isDesktop && !isMacOS;
  static bool get useNativeContextMenus => isDesktop;
  static bool get supportsSystemTray => isWindows || isLinux;
  
  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;
  static const double desktopBreakpoint = 1600;
  
  static String getPlatformName() {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }
  
  // Print configuration
  static bool get supportsPrinting => !isWeb || isDesktop;
  static bool get supportsBluetoothPrinting => isMobile;
  static bool get supportsNetworkPrinting => isDesktop || isWeb;
}