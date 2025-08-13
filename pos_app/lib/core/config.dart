import 'package:flutter/foundation.dart';

class AppConfig {
  // Toggle Firebase usage. In CI or if not configured, set to false.
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

  // Background sync interval in minutes
  static const int backgroundSyncIntervalMinutes = 5;

  // Default tax rate percent (e.g., 7.5 => 7.5%)
  static const double defaultTaxRatePercent = 0.0;

  // Whether to enable camera scanner features on web/desktop
  static bool get enableScanner => !kIsWeb || kIsWeb; // enabled everywhere by default
}