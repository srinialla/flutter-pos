import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../utils/platform_utils.dart';
import 'local_storage_service.dart';
import 'auth_service.dart';

class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final FirebasePerformance _performance = FirebasePerformance.instance;
  
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AuthService _authService = AuthService.instance;

  bool _isInitialized = false;
  final Map<String, Trace> _activeTraces = {};
  final List<Map<String, dynamic>> _pendingEvents = [];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase Analytics
      await _analytics.setAnalyticsCollectionEnabled(true);
      
      // Set default parameters
      await _analytics.setDefaultParameters({
        'platform': PlatformUtils.getPlatformName(),
        'app_version': '1.0.0',
        'device_type': PlatformUtils.isMobile ? 'mobile' : 
                      PlatformUtils.isWeb ? 'web' : 'desktop',
      });

      // Initialize Crashlytics
      if (!kDebugMode) {
        await _crashlytics.setCrashlyticsCollectionEnabled(true);
        
        // Set user identifier
        if (_authService.isLoggedIn) {
          await _crashlytics.setUserIdentifier(_authService.currentUserId!);
        }
      }

      // Initialize Sentry for additional error tracking
      if (!kDebugMode) {
        await SentryFlutter.init(
          (options) {
            options.dsn = 'YOUR_SENTRY_DSN'; // Replace with actual DSN
            options.environment = kDebugMode ? 'debug' : 'production';
            options.tracesSampleRate = 0.1;
          },
        );
      }

      _isInitialized = true;
      debugPrint('Analytics service initialized successfully');
      
      // Send pending events
      await _sendPendingEvents();
      
      // Track app startup
      await trackEvent('app_startup', {
        'platform': PlatformUtils.getPlatformName(),
        'startup_time': DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      debugPrint('Analytics initialization failed: $e');
      await recordError(e, StackTrace.current, 'analytics_init_failed');
    }
  }

  // Event Tracking
  Future<void> trackEvent(String eventName, [Map<String, dynamic>? parameters]) async {
    try {
      final enrichedParams = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': _authService.currentUserId,
        'session_id': await _getSessionId(),
        ...?parameters,
      };

      if (_isInitialized) {
        await _analytics.logEvent(
          name: eventName,
          parameters: _sanitizeParameters(enrichedParams),
        );
      } else {
        // Queue event for later
        _pendingEvents.add({
          'event': eventName,
          'parameters': enrichedParams,
        });
      }

      // Store locally for offline analysis
      await _storeLocalEvent(eventName, enrichedParams);

    } catch (e) {
      debugPrint('Failed to track event $eventName: $e');
    }
  }

  // Business-specific event tracking
  Future<void> trackSale(Sale sale) async {
    await trackEvent('sale_completed', {
      'sale_id': sale.id,
      'total_amount': sale.total,
      'item_count': sale.items.length,
      'payment_method': sale.paymentMethod.toString(),
      'discount_amount': sale.discount,
      'tax_amount': sale.taxAmount,
    });

    // Track individual items
    for (final item in sale.items) {
      await trackEvent('item_sold', {
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.total,
      });
    }

    // Update user properties
    await _updateUserSalesMetrics();
  }

  Future<void> trackProductAction(String action, Product product) async {
    await trackEvent('product_$action', {
      'product_id': product.id,
      'product_name': product.name,
      'category': product.category,
      'price': product.price,
      'stock_quantity': product.stockQuantity,
    });
  }

  Future<void> trackUserAction(String action, [Map<String, dynamic>? extra]) async {
    await trackEvent('user_$action', {
      'action': action,
      ...?extra,
    });
  }

  Future<void> trackNavigation(String screenName, [String? previousScreen]) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
    );

    await trackEvent('screen_view', {
      'screen_name': screenName,
      'previous_screen': previousScreen,
    });
  }

  Future<void> trackPerformance(String operation, int durationMs, [Map<String, dynamic>? extra]) async {
    await trackEvent('performance_metric', {
      'operation': operation,
      'duration_ms': durationMs,
      'platform': PlatformUtils.getPlatformName(),
      ...?extra,
    });
  }

  // Performance Monitoring
  Future<T> measurePerformance<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    Trace? trace;
    final stopwatch = Stopwatch()..start();

    try {
      if (_isInitialized && !PlatformUtils.isWeb) {
        trace = _performance.newTrace(traceName);
        if (attributes != null) {
          for (final entry in attributes.entries) {
            trace.putAttribute(entry.key, entry.value);
          }
        }
        await trace.start();
        _activeTraces[traceName] = trace;
      }

      final result = await operation();
      
      stopwatch.stop();
      
      // Track performance metric
      await trackPerformance(traceName, stopwatch.elapsedMilliseconds, {
        'success': true,
        'attributes': attributes,
      });

      return result;
    } catch (e) {
      stopwatch.stop();
      
      // Track failed operation
      await trackPerformance(traceName, stopwatch.elapsedMilliseconds, {
        'success': false,
        'error': e.toString(),
        'attributes': attributes,
      });

      await recordError(e, StackTrace.current, 'performance_operation_failed');
      rethrow;
    } finally {
      if (trace != null) {
        await trace.stop();
        _activeTraces.remove(traceName);
      }
    }
  }

  Future<void> startTrace(String traceName, [Map<String, String>? attributes]) async {
    try {
      if (!_isInitialized || PlatformUtils.isWeb) return;

      final trace = _performance.newTrace(traceName);
      if (attributes != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }
      
      await trace.start();
      _activeTraces[traceName] = trace;
    } catch (e) {
      debugPrint('Failed to start trace $traceName: $e');
    }
  }

  Future<void> stopTrace(String traceName) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        await trace.stop();
        _activeTraces.remove(traceName);
      }
    } catch (e) {
      debugPrint('Failed to stop trace $traceName: $e');
    }
  }

  // Error Tracking
  Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, [
    String? context,
    Map<String, dynamic>? extra,
  ]) async {
    try {
      debugPrint('Recording error: $error');
      
      // Firebase Crashlytics
      if (_isInitialized && !kDebugMode) {
        await _crashlytics.recordError(
          error,
          stackTrace,
          reason: context,
          information: extra?.entries.map((e) => 
              DiagnosticsProperty(e.key, e.value)).toList() ?? [],
        );
      }

      // Sentry
      if (!kDebugMode) {
        await Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            if (context != null) scope.setTag('context', context);
            if (extra != null) {
              for (final entry in extra.entries) {
                scope.setExtra(entry.key, entry.value);
              }
            }
          },
        );
      }

      // Local storage for offline analysis
      await _storeLocalError(error, stackTrace, context, extra);

      // Track as analytics event
      await trackEvent('error_occurred', {
        'error_type': error.runtimeType.toString(),
        'error_message': error.toString(),
        'context': context,
        'has_stack_trace': stackTrace != null,
      });

    } catch (e) {
      debugPrint('Failed to record error: $e');
    }
  }

  Future<void> recordCustomError(String message, [Map<String, dynamic>? extra]) async {
    await recordError(
      Exception(message),
      StackTrace.current,
      'custom_error',
      extra,
    );
  }

  // User Analytics
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    try {
      if (!_isInitialized) return;

      for (final entry in properties.entries) {
        await _analytics.setUserProperty(
          name: entry.key,
          value: entry.value?.toString(),
        );
      }

      // Also set in Crashlytics
      if (!kDebugMode) {
        for (final entry in properties.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }
    } catch (e) {
      debugPrint('Failed to set user properties: $e');
    }
  }

  Future<void> _updateUserSalesMetrics() async {
    try {
      final sales = _localStorage.getAllSales();
      final totalSales = sales.length;
      final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
      final avgOrderValue = totalSales > 0 ? totalRevenue / totalSales : 0;

      await setUserProperties({
        'total_sales': totalSales,
        'total_revenue': totalRevenue.toStringAsFixed(2),
        'avg_order_value': avgOrderValue.toStringAsFixed(2),
        'last_sale_date': sales.isNotEmpty 
            ? sales.last.createdAt.toIso8601String().split('T')[0]
            : null,
      });
    } catch (e) {
      debugPrint('Failed to update user sales metrics: $e');
    }
  }

  // Business Intelligence
  Future<Map<String, dynamic>> getBusinessAnalytics() async {
    try {
      final sales = _localStorage.getAllSales();
      final products = _localStorage.getAllProducts();
      
      return {
        'overview': _getOverviewMetrics(sales, products),
        'sales_trends': _getSalesTrends(sales),
        'product_performance': _getProductPerformance(sales, products),
        'time_analysis': _getTimeAnalysis(sales),
        'performance_metrics': await _getPerformanceMetrics(),
      };
    } catch (e) {
      await recordError(e, StackTrace.current, 'business_analytics_failed');
      return {};
    }
  }

  Map<String, dynamic> _getOverviewMetrics(List<Sale> sales, List<Product> products) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = now.subtract(Duration(days: now.weekday - 1));
    final thisMonth = DateTime(now.year, now.month, 1);

    final todaySales = sales.where((s) => s.createdAt.isAfter(today)).toList();
    final yesterdaySales = sales.where((s) => 
        s.createdAt.isAfter(yesterday) && s.createdAt.isBefore(today)).toList();
    final weekSales = sales.where((s) => s.createdAt.isAfter(thisWeek)).toList();
    final monthSales = sales.where((s) => s.createdAt.isAfter(thisMonth)).toList();

    return {
      'total_sales': sales.length,
      'total_revenue': sales.fold<double>(0, (sum, sale) => sum + sale.total),
      'total_products': products.length,
      'today': {
        'sales_count': todaySales.length,
        'revenue': todaySales.fold<double>(0, (sum, sale) => sum + sale.total),
        'vs_yesterday': _calculateGrowth(
          todaySales.fold<double>(0, (sum, sale) => sum + sale.total),
          yesterdaySales.fold<double>(0, (sum, sale) => sum + sale.total),
        ),
      },
      'this_week': {
        'sales_count': weekSales.length,
        'revenue': weekSales.fold<double>(0, (sum, sale) => sum + sale.total),
      },
      'this_month': {
        'sales_count': monthSales.length,
        'revenue': monthSales.fold<double>(0, (sum, sale) => sum + sale.total),
      },
      'avg_order_value': sales.isNotEmpty 
          ? sales.fold<double>(0, (sum, sale) => sum + sale.total) / sales.length 
          : 0,
      'low_stock_count': products.where((p) => p.stockQuantity <= 10).length,
    };
  }

  Map<String, dynamic> _getSalesTrends(List<Sale> sales) {
    final dailySales = <String, double>{};
    final hourlySales = <int, int>{};
    final dayOfWeekSales = <int, double>{};

    for (final sale in sales) {
      // Daily trends
      final dateKey = '${sale.createdAt.year}-${sale.createdAt.month.toString().padLeft(2, '0')}-${sale.createdAt.day.toString().padLeft(2, '0')}';
      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + sale.total;

      // Hourly trends
      final hour = sale.createdAt.hour;
      hourlySales[hour] = (hourlySales[hour] ?? 0) + 1;

      // Day of week trends
      final dayOfWeek = sale.createdAt.weekday;
      dayOfWeekSales[dayOfWeek] = (dayOfWeekSales[dayOfWeek] ?? 0) + sale.total;
    }

    return {
      'daily_sales': dailySales,
      'hourly_sales': hourlySales,
      'day_of_week_sales': dayOfWeekSales,
      'peak_hour': hourlySales.entries.reduce((a, b) => a.value > b.value ? a : b).key,
      'peak_day': dayOfWeekSales.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }

  Map<String, dynamic> _getProductPerformance(List<Sale> sales, List<Product> products) {
    final productSales = <String, Map<String, dynamic>>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final productId = item.productId;
        if (!productSales.containsKey(productId)) {
          productSales[productId] = {
            'name': item.productName,
            'quantity_sold': 0,
            'revenue': 0.0,
            'sales_count': 0,
          };
        }
        
        productSales[productId]!['quantity_sold'] += item.quantity;
        productSales[productId]!['revenue'] += item.total;
        productSales[productId]!['sales_count']++;
      }
    }

    // Sort by revenue
    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));

    return {
      'top_products': sortedProducts.take(10).map((e) => {
        'product_id': e.key,
        ...e.value,
      }).toList(),
      'total_products_sold': productSales.length,
      'avg_product_revenue': productSales.isNotEmpty 
          ? productSales.values.fold<double>(0, (sum, data) => sum + data['revenue']) / productSales.length
          : 0,
    };
  }

  Map<String, dynamic> _getTimeAnalysis(List<Sale> sales) {
    if (sales.isEmpty) return {};

    final sortedSales = List<Sale>.from(sales)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final firstSale = sortedSales.first.createdAt;
    final lastSale = sortedSales.last.createdAt;
    final timespan = lastSale.difference(firstSale);

    return {
      'first_sale': firstSale.toIso8601String(),
      'last_sale': lastSale.toIso8601String(),
      'timespan_days': timespan.inDays,
      'avg_sales_per_day': timespan.inDays > 0 ? sales.length / timespan.inDays : 0,
      'busiest_month': _getBusiestMonth(sales),
    };
  }

  String _getBusiestMonth(List<Sale> sales) {
    final monthSales = <String, int>{};
    
    for (final sale in sales) {
      final monthKey = '${sale.createdAt.year}-${sale.createdAt.month.toString().padLeft(2, '0')}';
      monthSales[monthKey] = (monthSales[monthKey] ?? 0) + 1;
    }

    if (monthSales.isEmpty) return 'No data';
    
    final busiest = monthSales.entries.reduce((a, b) => a.value > b.value ? a : b);
    return busiest.key;
  }

  Future<Map<String, dynamic>> _getPerformanceMetrics() async {
    try {
      final events = await _getLocalEvents();
      final performanceEvents = events.where((e) => e['event'] == 'performance_metric').toList();

      if (performanceEvents.isEmpty) {
        return {'message': 'No performance data available'};
      }

      final operations = <String, List<int>>{};
      for (final event in performanceEvents) {
        final operation = event['parameters']['operation'] as String;
        final duration = event['parameters']['duration_ms'] as int;
        
        operations[operation] = (operations[operation] ?? [])..add(duration);
      }

      final metrics = <String, dynamic>{};
      for (final entry in operations.entries) {
        final durations = entry.value;
        metrics[entry.key] = {
          'avg_duration': durations.fold<int>(0, (sum, d) => sum + d) / durations.length,
          'min_duration': durations.reduce(min),
          'max_duration': durations.reduce(max),
          'sample_count': durations.length,
        };
      }

      return metrics;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  double _calculateGrowth(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  // Local storage for offline analytics
  Future<void> _storeLocalEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      final events = await _getLocalEvents();
      events.add({
        'event': eventName,
        'parameters': parameters,
        'stored_at': DateTime.now().toIso8601String(),
      });

      // Keep only last 1000 events
      if (events.length > 1000) {
        events.removeRange(0, events.length - 1000);
      }

      await _localStorage.setSetting('analytics_events', json.encode(events));
    } catch (e) {
      debugPrint('Failed to store local event: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalEvents() async {
    try {
      final eventsJson = _localStorage.getSetting<String>('analytics_events');
      if (eventsJson == null) return [];
      
      final events = json.decode(eventsJson) as List;
      return events.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Failed to get local events: $e');
      return [];
    }
  }

  Future<void> _storeLocalError(
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  ) async {
    try {
      final errors = await _getLocalErrors();
      errors.add({
        'error': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'context': context,
        'extra': extra,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': PlatformUtils.getPlatformName(),
      });

      // Keep only last 100 errors
      if (errors.length > 100) {
        errors.removeRange(0, errors.length - 100);
      }

      await _localStorage.setSetting('analytics_errors', json.encode(errors));
    } catch (e) {
      debugPrint('Failed to store local error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalErrors() async {
    try {
      final errorsJson = _localStorage.getSetting<String>('analytics_errors');
      if (errorsJson == null) return [];
      
      final errors = json.decode(errorsJson) as List;
      return errors.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Failed to get local errors: $e');
      return [];
    }
  }

  // Utility methods
  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic> parameters) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in parameters.entries) {
      final value = entry.value;
      
      // Firebase Analytics has limitations on parameter values
      if (value is String && value.length > 100) {
        sanitized[entry.key] = value.substring(0, 100);
      } else if (value is num || value is String || value is bool) {
        sanitized[entry.key] = value;
      } else {
        sanitized[entry.key] = value.toString();
      }
    }
    
    return sanitized;
  }

  Future<String> _getSessionId() async {
    var sessionId = _localStorage.getSetting<String>('current_session_id');
    if (sessionId == null) {
      sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      await _localStorage.setSetting('current_session_id', sessionId);
    }
    return sessionId;
  }

  Future<void> _sendPendingEvents() async {
    try {
      for (final event in _pendingEvents) {
        await _analytics.logEvent(
          name: event['event'],
          parameters: _sanitizeParameters(event['parameters']),
        );
      }
      _pendingEvents.clear();
    } catch (e) {
      debugPrint('Failed to send pending events: $e');
    }
  }

  // Cleanup
  Future<void> dispose() async {
    // Stop all active traces
    for (final trace in _activeTraces.values) {
      try {
        await trace.stop();
      } catch (e) {
        debugPrint('Failed to stop trace: $e');
      }
    }
    _activeTraces.clear();
    _isInitialized = false;
  }
}