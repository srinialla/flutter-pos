import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/product.dart';
import '../models/purchase_order.dart';
import '../models/sale.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

class InventoryAlertsService {
  static InventoryAlertsService? _instance;
  static InventoryAlertsService get instance => _instance ??= InventoryAlertsService._();
  InventoryAlertsService._();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final NotificationService _notifications = NotificationService.instance;

  Timer? _alertCheckTimer;
  bool _isInitialized = false;
  
  // Alert configuration
  late InventoryAlertConfig _config;

  bool get isInitialized => _isInitialized;
  InventoryAlertConfig get config => _config;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadConfiguration();
      await _notifications.initialize();
      
      // Start periodic alert checking
      _startPeriodicChecks();
      
      _isInitialized = true;
      debugPrint('Inventory alerts service initialized');

      await _analytics.trackEvent('inventory_alerts_initialized', {
        'check_interval_minutes': _config.checkIntervalMinutes,
        'low_stock_enabled': _config.lowStockAlertsEnabled,
        'overstock_enabled': _config.overstockAlertsEnabled,
      });
    } catch (e) {
      debugPrint('Failed to initialize inventory alerts: $e');
      await _analytics.recordError(e, StackTrace.current, 'inventory_alerts_init_failed');
    }
  }

  Future<void> _loadConfiguration() async {
    final configMap = _localStorage.getSetting<Map<String, dynamic>>('inventory_alert_config');
    if (configMap != null) {
      _config = InventoryAlertConfig.fromMap(configMap);
    } else {
      _config = InventoryAlertConfig.defaultConfig();
      await saveConfiguration(_config);
    }
  }

  Future<void> saveConfiguration(InventoryAlertConfig config) async {
    _config = config;
    await _localStorage.setSetting('inventory_alert_config', config.toMap());
    
    // Restart timer with new interval
    _stopPeriodicChecks();
    if (_config.checkIntervalMinutes > 0) {
      _startPeriodicChecks();
    }

    await _analytics.trackEvent('inventory_alert_config_updated', {
      'check_interval_minutes': config.checkIntervalMinutes,
      'low_stock_threshold': config.defaultLowStockThreshold,
      'overstock_multiplier': config.overstockMultiplier,
    });
  }

  void _startPeriodicChecks() {
    if (_config.checkIntervalMinutes <= 0) return;
    
    _alertCheckTimer = Timer.periodic(
      Duration(minutes: _config.checkIntervalMinutes),
      (_) => checkAllAlerts(),
    );
  }

  void _stopPeriodicChecks() {
    _alertCheckTimer?.cancel();
    _alertCheckTimer = null;
  }

  // Main alert checking method
  Future<List<InventoryAlert>> checkAllAlerts() async {
    if (!_isInitialized) return [];

    try {
      final alerts = <InventoryAlert>[];
      final products = _localStorage.getAllProducts();

      for (final product in products) {
        alerts.addAll(await _checkProductAlerts(product));
      }

      // Remove duplicate alerts
      final uniqueAlerts = _removeDuplicateAlerts(alerts);

      // Process new alerts
      await _processNewAlerts(uniqueAlerts);

      await _analytics.trackEvent('inventory_alerts_checked', {
        'products_checked': products.length,
        'alerts_found': uniqueAlerts.length,
      });

      return uniqueAlerts;
    } catch (e) {
      debugPrint('Alert checking failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'inventory_alert_check_failed');
      return [];
    }
  }

  Future<List<InventoryAlert>> _checkProductAlerts(Product product) async {
    final alerts = <InventoryAlert>[];

    // Low stock alerts
    if (_config.lowStockAlertsEnabled) {
      final lowStockAlert = await _checkLowStock(product);
      if (lowStockAlert != null) {
        alerts.add(lowStockAlert);
      }
    }

    // Overstock alerts
    if (_config.overstockAlertsEnabled) {
      final overstockAlert = await _checkOverstock(product);
      if (overstockAlert != null) {
        alerts.add(overstockAlert);
      }
    }

    // Out of stock alerts
    if (_config.outOfStockAlertsEnabled) {
      final outOfStockAlert = _checkOutOfStock(product);
      if (outOfStockAlert != null) {
        alerts.add(outOfStockAlert);
      }
    }

    // Expiry alerts
    if (_config.expiryAlertsEnabled) {
      final expiryAlert = _checkExpiry(product);
      if (expiryAlert != null) {
        alerts.add(expiryAlert);
      }
    }

    // Slow moving stock alerts
    if (_config.slowMovingAlertsEnabled) {
      final slowMovingAlert = await _checkSlowMoving(product);
      if (slowMovingAlert != null) {
        alerts.add(slowMovingAlert);
      }
    }

    return alerts;
  }

  Future<InventoryAlert?> _checkLowStock(Product product) async {
    final threshold = product.lowStockThreshold ?? _config.defaultLowStockThreshold;
    
    if (product.stockQuantity <= threshold && product.stockQuantity > 0) {
      return InventoryAlert(
        id: 'low_stock_${product.id}',
        type: AlertType.lowStock,
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        threshold: threshold,
        severity: _getSeverity(product.stockQuantity, threshold),
        message: 'Low stock alert: ${product.name} has ${product.stockQuantity} units remaining (threshold: $threshold)',
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  Future<InventoryAlert?> _checkOverstock(Product product) async {
    // Calculate average sales over the last 30 days
    final sales = _localStorage.getAllSales();
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final recentSales = sales.where((sale) => 
        sale.createdAt.isAfter(thirtyDaysAgo)).toList();
    
    double totalSold = 0;
    for (final sale in recentSales) {
      final productItems = sale.items.where((item) => item.productId == product.id);
      totalSold += productItems.fold<double>(0, (sum, item) => sum + item.quantity);
    }
    
    final averageMonthlySales = totalSold;
    final overstockThreshold = averageMonthlySales * _config.overstockMultiplier;
    
    if (product.stockQuantity > overstockThreshold && overstockThreshold > 0) {
      return InventoryAlert(
        id: 'overstock_${product.id}',
        type: AlertType.overstock,
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        threshold: overstockThreshold.round(),
        severity: AlertSeverity.medium,
        message: 'Overstock alert: ${product.name} has ${product.stockQuantity} units (${overstockThreshold.round()} units expected)',
        createdAt: DateTime.now(),
        additionalData: {
          'monthly_sales': averageMonthlySales,
          'suggested_reorder_level': (averageMonthlySales * 1.5).round(),
        },
      );
    }
    return null;
  }

  InventoryAlert? _checkOutOfStock(Product product) {
    if (product.stockQuantity <= 0) {
      return InventoryAlert(
        id: 'out_of_stock_${product.id}',
        type: AlertType.outOfStock,
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        threshold: 0,
        severity: AlertSeverity.high,
        message: 'Out of stock: ${product.name} is completely out of stock',
        createdAt: DateTime.now(),
      );
    }
    return null;
  }

  InventoryAlert? _checkExpiry(Product product) {
    if (product.expiryDate == null) return null;
    
    final now = DateTime.now();
    final daysUntilExpiry = product.expiryDate!.difference(now).inDays;
    
    if (daysUntilExpiry <= _config.expiryWarningDays && daysUntilExpiry >= 0) {
      return InventoryAlert(
        id: 'expiry_${product.id}',
        type: AlertType.expiring,
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        threshold: _config.expiryWarningDays,
        severity: daysUntilExpiry <= 3 ? AlertSeverity.high : AlertSeverity.medium,
        message: 'Expiry warning: ${product.name} expires in $daysUntilExpiry days',
        createdAt: DateTime.now(),
        additionalData: {
          'expiry_date': product.expiryDate!.toIso8601String(),
          'days_until_expiry': daysUntilExpiry,
        },
      );
    }
    return null;
  }

  Future<InventoryAlert?> _checkSlowMoving(Product product) async {
    final sales = _localStorage.getAllSales();
    final checkPeriodDays = _config.slowMovingPeriodDays;
    final checkDate = DateTime.now().subtract(Duration(days: checkPeriodDays));
    
    final recentSales = sales.where((sale) => 
        sale.createdAt.isAfter(checkDate)).toList();
    
    bool hasSales = false;
    for (final sale in recentSales) {
      final hasProductSale = sale.items.any((item) => item.productId == product.id);
      if (hasProductSale) {
        hasSales = true;
        break;
      }
    }
    
    if (!hasSales && product.stockQuantity > 0) {
      return InventoryAlert(
        id: 'slow_moving_${product.id}',
        type: AlertType.slowMoving,
        productId: product.id,
        productName: product.name,
        currentStock: product.stockQuantity,
        threshold: checkPeriodDays,
        severity: AlertSeverity.low,
        message: 'Slow moving: ${product.name} has not sold in the last $checkPeriodDays days',
        createdAt: DateTime.now(),
        additionalData: {
          'check_period_days': checkPeriodDays,
          'last_sale_check': checkDate.toIso8601String(),
        },
      );
    }
    return null;
  }

  AlertSeverity _getSeverity(int currentStock, int threshold) {
    final ratio = currentStock / threshold;
    if (ratio <= 0.2) return AlertSeverity.high;
    if (ratio <= 0.5) return AlertSeverity.medium;
    return AlertSeverity.low;
  }

  List<InventoryAlert> _removeDuplicateAlerts(List<InventoryAlert> alerts) {
    final seen = <String>{};
    return alerts.where((alert) => seen.add(alert.id)).toList();
  }

  Future<void> _processNewAlerts(List<InventoryAlert> alerts) async {
    final existingAlerts = await getActiveAlerts();
    final existingIds = existingAlerts.map((a) => a.id).toSet();
    
    final newAlerts = alerts.where((alert) => !existingIds.contains(alert.id)).toList();
    
    if (newAlerts.isNotEmpty) {
      // Save new alerts
      for (final alert in newAlerts) {
        await _saveAlert(alert);
      }
      
      // Send notifications
      await _sendNotifications(newAlerts);
      
      await _analytics.trackEvent('new_inventory_alerts', {
        'count': newAlerts.length,
        'types': newAlerts.map((a) => a.type.toString()).toList(),
      });
    }
  }

  Future<void> _saveAlert(InventoryAlert alert) async {
    final alertsBox = await _localStorage.getBox<Map<String, dynamic>>('inventory_alerts');
    await alertsBox.put(alert.id, alert.toMap());
  }

  Future<void> _sendNotifications(List<InventoryAlert> alerts) async {
    if (!_config.notificationsEnabled) return;
    
    for (final alert in alerts) {
      if (_shouldSendNotification(alert)) {
        await _notifications.showNotification(
          id: alert.id.hashCode,
          title: _getNotificationTitle(alert),
          body: alert.message,
          payload: alert.id,
        );
      }
    }
  }

  bool _shouldSendNotification(InventoryAlert alert) {
    switch (alert.severity) {
      case AlertSeverity.high:
        return _config.highPriorityNotifications;
      case AlertSeverity.medium:
        return _config.mediumPriorityNotifications;
      case AlertSeverity.low:
        return _config.lowPriorityNotifications;
    }
  }

  String _getNotificationTitle(InventoryAlert alert) {
    switch (alert.type) {
      case AlertType.lowStock:
        return '⚠️ Low Stock Alert';
      case AlertType.outOfStock:
        return '🚫 Out of Stock';
      case AlertType.overstock:
        return '📦 Overstock Alert';
      case AlertType.expiring:
        return '⏰ Expiry Warning';
      case AlertType.slowMoving:
        return '📊 Slow Moving Stock';
    }
  }

  // Public API methods
  Future<List<InventoryAlert>> getActiveAlerts() async {
    try {
      final alertsBox = await _localStorage.getBox<Map<String, dynamic>>('inventory_alerts');
      final alertMaps = alertsBox.values.toList();
      
      return alertMaps
          .map((map) => InventoryAlert.fromMap(map))
          .where((alert) => !alert.isDismissed)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Failed to get active alerts: $e');
      return [];
    }
  }

  Future<List<InventoryAlert>> getAlertsByType(AlertType type) async {
    final alerts = await getActiveAlerts();
    return alerts.where((alert) => alert.type == type).toList();
  }

  Future<List<InventoryAlert>> getAlertsByProduct(String productId) async {
    final alerts = await getActiveAlerts();
    return alerts.where((alert) => alert.productId == productId).toList();
  }

  Future<void> dismissAlert(String alertId) async {
    try {
      final alertsBox = await _localStorage.getBox<Map<String, dynamic>>('inventory_alerts');
      final alertMap = alertsBox.get(alertId);
      
      if (alertMap != null) {
        final alert = InventoryAlert.fromMap(alertMap);
        final dismissedAlert = alert.copyWith(
          isDismissed: true,
          dismissedAt: DateTime.now(),
        );
        
        await alertsBox.put(alertId, dismissedAlert.toMap());
        
        await _analytics.trackEvent('inventory_alert_dismissed', {
          'alert_type': alert.type.toString(),
          'alert_severity': alert.severity.toString(),
        });
      }
    } catch (e) {
      debugPrint('Failed to dismiss alert: $e');
    }
  }

  Future<void> dismissAllAlerts() async {
    try {
      final alerts = await getActiveAlerts();
      for (final alert in alerts) {
        await dismissAlert(alert.id);
      }
    } catch (e) {
      debugPrint('Failed to dismiss all alerts: $e');
    }
  }

  // Reorder suggestions
  Future<List<ReorderSuggestion>> getReorderSuggestions() async {
    try {
      final products = _localStorage.getAllProducts();
      final suggestions = <ReorderSuggestion>[];
      
      for (final product in products) {
        final suggestion = await _calculateReorderSuggestion(product);
        if (suggestion != null) {
          suggestions.add(suggestion);
        }
      }
      
      // Sort by priority (low stock first, then by sales velocity)
      suggestions.sort((a, b) {
        if (a.priority != b.priority) {
          return b.priority.index.compareTo(a.priority.index);
        }
        return b.suggestedQuantity.compareTo(a.suggestedQuantity);
      });
      
      return suggestions;
    } catch (e) {
      debugPrint('Failed to get reorder suggestions: $e');
      return [];
    }
  }

  Future<ReorderSuggestion?> _calculateReorderSuggestion(Product product) async {
    // Only suggest reorder for products that are low on stock
    final threshold = product.lowStockThreshold ?? _config.defaultLowStockThreshold;
    if (product.stockQuantity > threshold) return null;
    
    // Calculate average sales velocity
    final sales = _localStorage.getAllSales();
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final recentSales = sales.where((sale) => 
        sale.createdAt.isAfter(thirtyDaysAgo)).toList();
    
    double totalSold = 0;
    for (final sale in recentSales) {
      final productItems = sale.items.where((item) => item.productId == product.id);
      totalSold += productItems.fold<double>(0, (sum, item) => sum + item.quantity);
    }
    
    final dailyAverageSales = totalSold / 30;
    final leadTimeDays = product.supplierLeadTimeDays ?? 7;
    final safetyStock = dailyAverageSales * 7; // 1 week safety stock
    
    final suggestedQuantity = ((dailyAverageSales * leadTimeDays) + safetyStock).round();
    
    if (suggestedQuantity <= 0) return null;
    
    return ReorderSuggestion(
      productId: product.id,
      productName: product.name,
      currentStock: product.stockQuantity,
      suggestedQuantity: suggestedQuantity,
      estimatedCost: (product.cost ?? 0) * suggestedQuantity,
      priority: product.stockQuantity <= 0 
          ? ReorderPriority.urgent 
          : product.stockQuantity <= threshold * 0.5 
              ? ReorderPriority.high 
              : ReorderPriority.medium,
      reason: _getReorderReason(product, threshold, dailyAverageSales),
      estimatedDeliveryDate: DateTime.now().add(Duration(days: leadTimeDays)),
    );
  }

  String _getReorderReason(Product product, int threshold, double dailyAverageSales) {
    if (product.stockQuantity <= 0) {
      return 'Out of stock - immediate reorder required';
    } else if (product.stockQuantity <= threshold * 0.5) {
      return 'Critically low stock - high priority reorder';
    } else {
      final daysRemaining = (product.stockQuantity / dailyAverageSales).round();
      return 'Low stock - approximately $daysRemaining days remaining';
    }
  }

  // Analytics and reporting
  Future<InventoryAlertsSummary> getAlertsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();
      
      final alertsBox = await _localStorage.getBox<Map<String, dynamic>>('inventory_alerts');
      final allAlerts = alertsBox.values
          .map((map) => InventoryAlert.fromMap(map))
          .where((alert) => 
              alert.createdAt.isAfter(start) && 
              alert.createdAt.isBefore(end))
          .toList();
      
      final summary = InventoryAlertsSummary(
        totalAlerts: allAlerts.length,
        lowStockAlerts: allAlerts.where((a) => a.type == AlertType.lowStock).length,
        outOfStockAlerts: allAlerts.where((a) => a.type == AlertType.outOfStock).length,
        overstockAlerts: allAlerts.where((a) => a.type == AlertType.overstock).length,
        expiringAlerts: allAlerts.where((a) => a.type == AlertType.expiring).length,
        slowMovingAlerts: allAlerts.where((a) => a.type == AlertType.slowMoving).length,
        highPriorityAlerts: allAlerts.where((a) => a.severity == AlertSeverity.high).length,
        mediumPriorityAlerts: allAlerts.where((a) => a.severity == AlertSeverity.medium).length,
        lowPriorityAlerts: allAlerts.where((a) => a.severity == AlertSeverity.low).length,
        dismissedAlerts: allAlerts.where((a) => a.isDismissed).length,
        activeAlerts: allAlerts.where((a) => !a.isDismissed).length,
        periodStart: start,
        periodEnd: end,
      );
      
      return summary;
    } catch (e) {
      debugPrint('Failed to get alerts summary: $e');
      return InventoryAlertsSummary.empty();
    }
  }

  // Cleanup
  Future<void> cleanupOldAlerts() async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _config.alertRetentionDays));
      final alertsBox = await _localStorage.getBox<Map<String, dynamic>>('inventory_alerts');
      
      final keysToRemove = <String>[];
      for (final entry in alertsBox.toMap().entries) {
        final alert = InventoryAlert.fromMap(entry.value);
        if (alert.createdAt.isBefore(cutoffDate)) {
          keysToRemove.add(entry.key);
        }
      }
      
      for (final key in keysToRemove) {
        await alertsBox.delete(key);
      }
      
      debugPrint('Cleaned up ${keysToRemove.length} old alerts');
    } catch (e) {
      debugPrint('Failed to cleanup old alerts: $e');
    }
  }

  Future<void> dispose() async {
    _stopPeriodicChecks();
    _isInitialized = false;
  }
}

// Data classes
class InventoryAlert {
  final String id;
  final AlertType type;
  final String productId;
  final String productName;
  final int currentStock;
  final int threshold;
  final AlertSeverity severity;
  final String message;
  final DateTime createdAt;
  final bool isDismissed;
  final DateTime? dismissedAt;
  final Map<String, dynamic> additionalData;

  InventoryAlert({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.threshold,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.isDismissed = false,
    this.dismissedAt,
    this.additionalData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'productId': productId,
      'productName': productName,
      'currentStock': currentStock,
      'threshold': threshold,
      'severity': severity.toString(),
      'message': message,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isDismissed': isDismissed,
      'dismissedAt': dismissedAt?.millisecondsSinceEpoch,
      'additionalData': additionalData,
    };
  }

  factory InventoryAlert.fromMap(Map<String, dynamic> map) {
    return InventoryAlert(
      id: map['id'],
      type: AlertType.values.firstWhere((e) => e.toString() == map['type']),
      productId: map['productId'],
      productName: map['productName'],
      currentStock: map['currentStock'],
      threshold: map['threshold'],
      severity: AlertSeverity.values.firstWhere((e) => e.toString() == map['severity']),
      message: map['message'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isDismissed: map['isDismissed'] ?? false,
      dismissedAt: map['dismissedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['dismissedAt'])
          : null,
      additionalData: Map<String, dynamic>.from(map['additionalData'] ?? {}),
    );
  }

  InventoryAlert copyWith({
    bool? isDismissed,
    DateTime? dismissedAt,
  }) {
    return InventoryAlert(
      id: id,
      type: type,
      productId: productId,
      productName: productName,
      currentStock: currentStock,
      threshold: threshold,
      severity: severity,
      message: message,
      createdAt: createdAt,
      isDismissed: isDismissed ?? this.isDismissed,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      additionalData: additionalData,
    );
  }
}

class InventoryAlertConfig {
  final bool lowStockAlertsEnabled;
  final bool outOfStockAlertsEnabled;
  final bool overstockAlertsEnabled;
  final bool expiryAlertsEnabled;
  final bool slowMovingAlertsEnabled;
  final bool notificationsEnabled;
  final bool highPriorityNotifications;
  final bool mediumPriorityNotifications;
  final bool lowPriorityNotifications;
  final int defaultLowStockThreshold;
  final double overstockMultiplier;
  final int expiryWarningDays;
  final int slowMovingPeriodDays;
  final int checkIntervalMinutes;
  final int alertRetentionDays;

  InventoryAlertConfig({
    this.lowStockAlertsEnabled = true,
    this.outOfStockAlertsEnabled = true,
    this.overstockAlertsEnabled = true,
    this.expiryAlertsEnabled = true,
    this.slowMovingAlertsEnabled = true,
    this.notificationsEnabled = true,
    this.highPriorityNotifications = true,
    this.mediumPriorityNotifications = true,
    this.lowPriorityNotifications = false,
    this.defaultLowStockThreshold = 10,
    this.overstockMultiplier = 3.0,
    this.expiryWarningDays = 7,
    this.slowMovingPeriodDays = 30,
    this.checkIntervalMinutes = 60,
    this.alertRetentionDays = 90,
  });

  factory InventoryAlertConfig.defaultConfig() {
    return InventoryAlertConfig();
  }

  Map<String, dynamic> toMap() {
    return {
      'lowStockAlertsEnabled': lowStockAlertsEnabled,
      'outOfStockAlertsEnabled': outOfStockAlertsEnabled,
      'overstockAlertsEnabled': overstockAlertsEnabled,
      'expiryAlertsEnabled': expiryAlertsEnabled,
      'slowMovingAlertsEnabled': slowMovingAlertsEnabled,
      'notificationsEnabled': notificationsEnabled,
      'highPriorityNotifications': highPriorityNotifications,
      'mediumPriorityNotifications': mediumPriorityNotifications,
      'lowPriorityNotifications': lowPriorityNotifications,
      'defaultLowStockThreshold': defaultLowStockThreshold,
      'overstockMultiplier': overstockMultiplier,
      'expiryWarningDays': expiryWarningDays,
      'slowMovingPeriodDays': slowMovingPeriodDays,
      'checkIntervalMinutes': checkIntervalMinutes,
      'alertRetentionDays': alertRetentionDays,
    };
  }

  factory InventoryAlertConfig.fromMap(Map<String, dynamic> map) {
    return InventoryAlertConfig(
      lowStockAlertsEnabled: map['lowStockAlertsEnabled'] ?? true,
      outOfStockAlertsEnabled: map['outOfStockAlertsEnabled'] ?? true,
      overstockAlertsEnabled: map['overstockAlertsEnabled'] ?? true,
      expiryAlertsEnabled: map['expiryAlertsEnabled'] ?? true,
      slowMovingAlertsEnabled: map['slowMovingAlertsEnabled'] ?? true,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      highPriorityNotifications: map['highPriorityNotifications'] ?? true,
      mediumPriorityNotifications: map['mediumPriorityNotifications'] ?? true,
      lowPriorityNotifications: map['lowPriorityNotifications'] ?? false,
      defaultLowStockThreshold: map['defaultLowStockThreshold'] ?? 10,
      overstockMultiplier: map['overstockMultiplier']?.toDouble() ?? 3.0,
      expiryWarningDays: map['expiryWarningDays'] ?? 7,
      slowMovingPeriodDays: map['slowMovingPeriodDays'] ?? 30,
      checkIntervalMinutes: map['checkIntervalMinutes'] ?? 60,
      alertRetentionDays: map['alertRetentionDays'] ?? 90,
    );
  }
}

class ReorderSuggestion {
  final String productId;
  final String productName;
  final int currentStock;
  final int suggestedQuantity;
  final double estimatedCost;
  final ReorderPriority priority;
  final String reason;
  final DateTime estimatedDeliveryDate;

  ReorderSuggestion({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.suggestedQuantity,
    required this.estimatedCost,
    required this.priority,
    required this.reason,
    required this.estimatedDeliveryDate,
  });
}

class InventoryAlertsSummary {
  final int totalAlerts;
  final int lowStockAlerts;
  final int outOfStockAlerts;
  final int overstockAlerts;
  final int expiringAlerts;
  final int slowMovingAlerts;
  final int highPriorityAlerts;
  final int mediumPriorityAlerts;
  final int lowPriorityAlerts;
  final int dismissedAlerts;
  final int activeAlerts;
  final DateTime periodStart;
  final DateTime periodEnd;

  InventoryAlertsSummary({
    required this.totalAlerts,
    required this.lowStockAlerts,
    required this.outOfStockAlerts,
    required this.overstockAlerts,
    required this.expiringAlerts,
    required this.slowMovingAlerts,
    required this.highPriorityAlerts,
    required this.mediumPriorityAlerts,
    required this.lowPriorityAlerts,
    required this.dismissedAlerts,
    required this.activeAlerts,
    required this.periodStart,
    required this.periodEnd,
  });

  factory InventoryAlertsSummary.empty() {
    final now = DateTime.now();
    return InventoryAlertsSummary(
      totalAlerts: 0,
      lowStockAlerts: 0,
      outOfStockAlerts: 0,
      overstockAlerts: 0,
      expiringAlerts: 0,
      slowMovingAlerts: 0,
      highPriorityAlerts: 0,
      mediumPriorityAlerts: 0,
      lowPriorityAlerts: 0,
      dismissedAlerts: 0,
      activeAlerts: 0,
      periodStart: now,
      periodEnd: now,
    );
  }
}

enum AlertType {
  lowStock,
  outOfStock,
  overstock,
  expiring,
  slowMoving,
}

enum AlertSeverity {
  low,
  medium,
  high,
}

enum ReorderPriority {
  low,
  medium,
  high,
  urgent,
}

extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.lowStock:
        return 'Low Stock';
      case AlertType.outOfStock:
        return 'Out of Stock';
      case AlertType.overstock:
        return 'Overstock';
      case AlertType.expiring:
        return 'Expiring Soon';
      case AlertType.slowMoving:
        return 'Slow Moving';
    }
  }
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.high:
        return 'High';
    }
  }
}

extension ReorderPriorityExtension on ReorderPriority {
  String get displayName {
    switch (this) {
      case ReorderPriority.low:
        return 'Low';
      case ReorderPriority.medium:
        return 'Medium';
      case ReorderPriority.high:
        return 'High';
      case ReorderPriority.urgent:
        return 'Urgent';
    }
  }
}