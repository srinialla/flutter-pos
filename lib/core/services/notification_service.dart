import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/platform_utils.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  bool _isInitialized = false;
  bool _permissionsGranted = false;
  late NotificationSettings _settings;

  bool get isInitialized => _isInitialized;
  bool get permissionsGranted => _permissionsGranted;
  NotificationSettings get settings => _settings;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSettings();
      await _requestPermissions();
      await _initializePlugin();
      
      _isInitialized = true;
      debugPrint('Notification service initialized');

      await _analytics.trackEvent('notification_service_initialized', {
        'permissions_granted': _permissionsGranted,
        'platform': PlatformUtils.getPlatformName(),
      });
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'notification_init_failed');
    }
  }

  Future<void> _loadSettings() async {
    final settingsMap = _localStorage.getSetting<Map<String, dynamic>>('notification_settings');
    if (settingsMap != null) {
      _settings = NotificationSettings.fromMap(settingsMap);
    } else {
      _settings = NotificationSettings.defaultSettings();
      await saveSettings(_settings);
    }
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    _settings = settings;
    await _localStorage.setSetting('notification_settings', settings.toMap());
    
    await _analytics.trackEvent('notification_settings_updated', {
      'enabled': settings.enabled,
      'sound_enabled': settings.soundEnabled,
      'vibration_enabled': settings.vibrationEnabled,
    });
  }

  Future<void> _requestPermissions() async {
    if (PlatformUtils.isAndroid) {
      final status = await Permission.notification.request();
      _permissionsGranted = status.isGranted;

      // For Android 13+ (API 33+), request POST_NOTIFICATIONS permission
      if (Platform.isAndroid) {
        final androidInfo = await PlatformUtils.getAndroidInfo();
        if (androidInfo != null && androidInfo.version.sdkInt >= 33) {
          _permissionsGranted = await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestPermission() ?? false;
        }
      }
    } else if (PlatformUtils.isIOS) {
      _permissionsGranted = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ?? false;
    } else {
      _permissionsGranted = true; // Desktop platforms don't need permissions
    }
  }

  Future<void> _initializePlugin() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
          macOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // Create notification channels for Android
    if (PlatformUtils.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel salesChannel = AndroidNotificationChannel(
      'sales_channel',
      'Sales Notifications',
      description: 'Notifications for sales and transactions',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const AndroidNotificationChannel inventoryChannel = AndroidNotificationChannel(
      'inventory_channel',
      'Inventory Alerts',
      description: 'Low stock and inventory alerts',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const AndroidNotificationChannel refundChannel = AndroidNotificationChannel(
      'refund_channel',
      'Refund Notifications',
      description: 'Refund approval and completion notifications',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const AndroidNotificationChannel systemChannel = AndroidNotificationChannel(
      'system_channel',
      'System Notifications',
      description: 'System updates and maintenance notifications',
      importance: Importance.defaultImportance,
    );

    final plugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (plugin != null) {
      await plugin.createNotificationChannel(salesChannel);
      await plugin.createNotificationChannel(inventoryChannel);
      await plugin.createNotificationChannel(refundChannel);
      await plugin.createNotificationChannel(systemChannel);
    }
  }

  // Show notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationChannel channel = NotificationChannel.system,
    NotificationPriority priority = NotificationPriority.normal,
    bool sound = true,
    bool vibration = true,
  }) async {
    if (!_isInitialized || !_permissionsGranted || !_settings.enabled) {
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _getChannelId(channel),
        _getChannelName(channel),
        channelDescription: _getChannelDescription(channel),
        importance: _getAndroidImportance(priority),
        priority: _getAndroidPriority(priority),
        playSound: sound && _settings.soundEnabled,
        enableVibration: vibration && _settings.vibrationEnabled,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: sound && _settings.soundEnabled,
        sound: sound && _settings.soundEnabled ? 'default' : null,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      await _analytics.trackEvent('notification_shown', {
        'id': id,
        'title': title,
        'channel': channel.toString(),
        'priority': priority.toString(),
      });
    } catch (e) {
      debugPrint('Failed to show notification: $e');
      await _analytics.recordError(e, StackTrace.current, 'notification_show_failed');
    }
  }

  // Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationChannel channel = NotificationChannel.system,
    NotificationPriority priority = NotificationPriority.normal,
  }) async {
    if (!_isInitialized || !_permissionsGranted || !_settings.enabled) {
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _getChannelId(channel),
        _getChannelName(channel),
        channelDescription: _getChannelDescription(channel),
        importance: _getAndroidImportance(priority),
        priority: _getAndroidPriority(priority),
        playSound: _settings.soundEnabled,
        enableVibration: _settings.vibrationEnabled,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: _settings.soundEnabled,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        TZDateTime.from(scheduledDate, TZLocal()),
        notificationDetails,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      await _analytics.trackEvent('notification_scheduled', {
        'id': id,
        'title': title,
        'scheduled_for': scheduledDate.toIso8601String(),
        'channel': channel.toString(),
      });
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
      await _analytics.recordError(e, StackTrace.current, 'notification_schedule_failed');
    }
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    
    await _analytics.trackEvent('notification_cancelled', {
      'id': id,
    });
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    
    await _analytics.trackEvent('all_notifications_cancelled');
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Show quick notification for common scenarios
  Future<void> showSaleNotification({
    required String receiptNumber,
    required double amount,
    required String customerName,
  }) async {
    await showNotification(
      id: receiptNumber.hashCode,
      title: '💰 Sale Completed',
      body: '${customerName.isNotEmpty ? customerName : 'Customer'} - \$${amount.toStringAsFixed(2)} (${receiptNumber})',
      channel: NotificationChannel.sales,
      priority: NotificationPriority.normal,
      payload: 'sale:$receiptNumber',
    );
  }

  Future<void> showLowStockAlert({
    required String productName,
    required int currentStock,
    required int threshold,
  }) async {
    await showNotification(
      id: productName.hashCode,
      title: '⚠️ Low Stock Alert',
      body: '$productName: $currentStock units left (threshold: $threshold)',
      channel: NotificationChannel.inventory,
      priority: NotificationPriority.high,
      payload: 'low_stock:$productName',
    );
  }

  Future<void> showRefundApprovalRequest({
    required String refundNumber,
    required double amount,
  }) async {
    await showNotification(
      id: refundNumber.hashCode,
      title: '💰 Refund Approval Required',
      body: 'Refund $refundNumber for \$${amount.toStringAsFixed(2)} needs manager approval',
      channel: NotificationChannel.refund,
      priority: NotificationPriority.high,
      payload: 'refund_approval:$refundNumber',
    );
  }

  Future<void> showSystemUpdate({
    required String title,
    required String message,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: '🔧 $title',
      body: message,
      channel: NotificationChannel.system,
      priority: NotificationPriority.normal,
    );
  }

  // Notification handling
  static void _onNotificationTapped(NotificationResponse response) {
    _handleNotificationTap(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    _handleNotificationTap(response.payload);
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    // Parse payload and handle navigation
    if (payload.startsWith('sale:')) {
      final receiptNumber = payload.substring(5);
      // Navigate to sale details
      debugPrint('Navigate to sale: $receiptNumber');
    } else if (payload.startsWith('low_stock:')) {
      final productName = payload.substring(10);
      // Navigate to inventory
      debugPrint('Navigate to inventory for: $productName');
    } else if (payload.startsWith('refund_approval:')) {
      final refundNumber = payload.substring(16);
      // Navigate to refund approval
      debugPrint('Navigate to refund approval: $refundNumber');
    }
  }

  // Helper methods
  String _getChannelId(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.sales:
        return 'sales_channel';
      case NotificationChannel.inventory:
        return 'inventory_channel';
      case NotificationChannel.refund:
        return 'refund_channel';
      case NotificationChannel.system:
        return 'system_channel';
    }
  }

  String _getChannelName(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.sales:
        return 'Sales Notifications';
      case NotificationChannel.inventory:
        return 'Inventory Alerts';
      case NotificationChannel.refund:
        return 'Refund Notifications';
      case NotificationChannel.system:
        return 'System Notifications';
    }
  }

  String _getChannelDescription(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.sales:
        return 'Notifications for sales and transactions';
      case NotificationChannel.inventory:
        return 'Low stock and inventory alerts';
      case NotificationChannel.refund:
        return 'Refund approval and completion notifications';
      case NotificationChannel.system:
        return 'System updates and maintenance notifications';
    }
  }

  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}

// Supporting classes
class NotificationSettings {
  final bool enabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool badgeEnabled;
  final List<NotificationChannel> enabledChannels;
  final Map<NotificationChannel, bool> channelSettings;

  NotificationSettings({
    this.enabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.badgeEnabled = true,
    this.enabledChannels = const [
      NotificationChannel.sales,
      NotificationChannel.inventory,
      NotificationChannel.refund,
      NotificationChannel.system,
    ],
    this.channelSettings = const {},
  });

  factory NotificationSettings.defaultSettings() {
    return NotificationSettings(
      channelSettings: {
        NotificationChannel.sales: true,
        NotificationChannel.inventory: true,
        NotificationChannel.refund: true,
        NotificationChannel.system: true,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'badgeEnabled': badgeEnabled,
      'enabledChannels': enabledChannels.map((c) => c.toString()).toList(),
      'channelSettings': channelSettings.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] ?? true,
      soundEnabled: map['soundEnabled'] ?? true,
      vibrationEnabled: map['vibrationEnabled'] ?? true,
      badgeEnabled: map['badgeEnabled'] ?? true,
      enabledChannels: (map['enabledChannels'] as List?)
          ?.map((c) => NotificationChannel.values.firstWhere((ch) => ch.toString() == c))
          .toList() ?? [],
      channelSettings: Map<NotificationChannel, bool>.fromEntries(
        (map['channelSettings'] as Map?)?.entries.map((e) => 
          MapEntry(
            NotificationChannel.values.firstWhere((ch) => ch.toString() == e.key),
            e.value as bool,
          )
        ) ?? [],
      ),
    );
  }

  bool isChannelEnabled(NotificationChannel channel) {
    return enabled && (channelSettings[channel] ?? true);
  }
}

enum NotificationChannel {
  sales,
  inventory,
  refund,
  system,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

// Missing imports that need to be added to pubspec.yaml
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// Timezone initialization (call in main.dart)
class TZDateTime {
  static DateTime from(DateTime dateTime, tz.Location location) {
    return tz.TZDateTime.from(dateTime, location);
  }
}

class TZLocal {
  static tz.Location call() {
    return tz.local;
  }
}