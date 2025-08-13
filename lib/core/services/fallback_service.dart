import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:retry/retry.dart';

import '../utils/platform_utils.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';

class FallbackService {
  static FallbackService? _instance;
  static FallbackService get instance => _instance ??= FallbackService._();
  FallbackService._();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final Connectivity _connectivity = Connectivity();

  // Fallback states
  bool _isOfflineMode = false;
  bool _isSyncDegraded = false;
  bool _isCameraDegraded = false;
  bool _isFirebaseDegraded = false;
  
  // Error tracking
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final Map<String, List<String>> _errorMessages = {};
  
  // Retry configurations
  static const Duration _retryDelay = Duration(seconds: 2);
  static const int _maxRetries = 3;
  static const Duration _degradedServiceTimeout = Duration(minutes: 5);
  static const int _maxErrorsBeforeDegradation = 5;

  // Offline queue
  final List<Map<String, dynamic>> _offlineQueue = [];
  Timer? _retryTimer;
  
  bool get isOfflineMode => _isOfflineMode;
  bool get isSyncDegraded => _isSyncDegraded;
  bool get isCameraDegraded => _isCameraDegraded;
  bool get isFirebaseDegraded => _isFirebaseDegraded;
  bool get hasQueuedOperations => _offlineQueue.isNotEmpty;
  int get queuedOperationsCount => _offlineQueue.length;

  Future<void> initialize() async {
    try {
      // Check initial connectivity
      await _checkConnectivity();
      
      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      
      // Load persisted offline queue
      await _loadOfflineQueue();
      
      // Start retry timer
      _startRetryTimer();
      
      debugPrint('Fallback service initialized');
      
      await _analytics.trackEvent('fallback_service_initialized', {
        'offline_mode': _isOfflineMode,
        'queued_operations': _offlineQueue.length,
      });
    } catch (e) {
      debugPrint('Fallback service initialization failed: $e');
    }
  }

  // Network Management
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasOffline = _isOfflineMode;
      _isOfflineMode = result == ConnectivityResult.none;
      
      if (wasOffline && !_isOfflineMode) {
        await _onConnectionRestored();
      } else if (!wasOffline && _isOfflineMode) {
        await _onConnectionLost();
      }
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      _isOfflineMode = true;
    }
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOffline = _isOfflineMode;
    _isOfflineMode = result == ConnectivityResult.none;
    
    if (wasOffline && !_isOfflineMode) {
      _onConnectionRestored();
    } else if (!wasOffline && _isOfflineMode) {
      _onConnectionLost();
    }
  }

  Future<void> _onConnectionRestored() async {
    debugPrint('Connection restored - processing offline queue');
    
    await _analytics.trackEvent('connection_restored', {
      'queued_operations': _offlineQueue.length,
    });
    
    // Process offline queue
    await _processOfflineQueue();
    
    // Reset degraded services
    await _resetDegradedServices();
  }

  Future<void> _onConnectionLost() async {
    debugPrint('Connection lost - entering offline mode');
    
    await _analytics.trackEvent('connection_lost');
  }

  // Error Handling and Degradation
  Future<T> executeWithFallback<T>(
    String operationName,
    Future<T> Function() primaryOperation,
    Future<T> Function() fallbackOperation, {
    bool allowOfflineQueue = true,
    Map<String, dynamic>? queueData,
  }) async {
    try {
      // Check if service is degraded
      if (_isServiceDegraded(operationName)) {
        debugPrint('Service $operationName is degraded, using fallback');
        return await fallbackOperation();
      }

      // Try primary operation with retry
      return await _retryOperation(operationName, primaryOperation);
    } catch (e) {
      await _recordError(operationName, e);
      
      // Check if we should degrade the service
      if (_shouldDegradeService(operationName)) {
        await _degradeService(operationName);
      }
      
      // Try fallback operation
      try {
        final result = await fallbackOperation();
        
        // Queue operation for retry if offline and allowed
        if (_isOfflineMode && allowOfflineQueue && queueData != null) {
          await _queueOperation(operationName, queueData);
        }
        
        return result;
      } catch (fallbackError) {
        await _recordError('${operationName}_fallback', fallbackError);
        
        // Queue operation if offline
        if (_isOfflineMode && allowOfflineQueue && queueData != null) {
          await _queueOperation(operationName, queueData);
        }
        
        rethrow;
      }
    }
  }

  Future<T> _retryOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return await retry(
      operation,
      retryIf: (e) => _shouldRetryError(e),
      maxAttempts: _maxRetries,
      delay: (attempt) => _retryDelay * pow(2, attempt - 1),
      onRetry: (e) async {
        debugPrint('Retrying $operationName (attempt ${_maxRetries - 2}): $e');
        await _analytics.trackEvent('operation_retry', {
          'operation': operationName,
          'error': e.toString(),
        });
      },
    );
  }

  bool _shouldRetryError(Exception e) {
    // Retry on network errors, timeout errors, etc.
    final errorString = e.toString().toLowerCase();
    return errorString.contains('network') ||
           errorString.contains('timeout') ||
           errorString.contains('connection') ||
           errorString.contains('unreachable');
  }

  Future<void> _recordError(String operationName, dynamic error) async {
    _errorCounts[operationName] = (_errorCounts[operationName] ?? 0) + 1;
    _lastErrorTimes[operationName] = DateTime.now();
    
    _errorMessages[operationName] = (_errorMessages[operationName] ?? [])
      ..add(error.toString());
    
    // Keep only last 10 error messages
    if (_errorMessages[operationName]!.length > 10) {
      _errorMessages[operationName]!.removeAt(0);
    }
    
    await _analytics.recordError(error, StackTrace.current, 'fallback_operation_failed', {
      'operation': operationName,
      'error_count': _errorCounts[operationName],
    });
  }

  bool _shouldDegradeService(String operationName) {
    final errorCount = _errorCounts[operationName] ?? 0;
    final lastError = _lastErrorTimes[operationName];
    
    if (lastError == null) return false;
    
    // Degrade if too many errors in short time
    final recentErrors = errorCount >= _maxErrorsBeforeDegradation;
    final recentTime = DateTime.now().difference(lastError) < const Duration(minutes: 1);
    
    return recentErrors && recentTime;
  }

  bool _isServiceDegraded(String operationName) {
    switch (operationName) {
      case 'firebase_sync':
        return _isFirebaseDegraded;
      case 'camera_scan':
        return _isCameraDegraded;
      default:
        return false;
    }
  }

  Future<void> _degradeService(String operationName) async {
    debugPrint('Degrading service: $operationName');
    
    switch (operationName) {
      case 'firebase_sync':
        _isFirebaseDegraded = true;
        break;
      case 'camera_scan':
        _isCameraDegraded = true;
        break;
    }
    
    await _analytics.trackEvent('service_degraded', {
      'service': operationName,
      'error_count': _errorCounts[operationName],
    });
    
    // Schedule service restoration
    Timer(_degradedServiceTimeout, () => _restoreService(operationName));
  }

  Future<void> _restoreService(String operationName) async {
    debugPrint('Restoring service: $operationName');
    
    switch (operationName) {
      case 'firebase_sync':
        _isFirebaseDegraded = false;
        break;
      case 'camera_scan':
        _isCameraDegraded = false;
        break;
    }
    
    // Reset error counts
    _errorCounts[operationName] = 0;
    _errorMessages[operationName]?.clear();
    
    await _analytics.trackEvent('service_restored', {
      'service': operationName,
    });
  }

  Future<void> _resetDegradedServices() async {
    _isFirebaseDegraded = false;
    _isCameraDegraded = false;
    _isSyncDegraded = false;
    
    _errorCounts.clear();
    _errorMessages.clear();
    _lastErrorTimes.clear();
  }

  // Offline Queue Management
  Future<void> _queueOperation(String operationName, Map<String, dynamic> data) async {
    final operation = {
      'operation': operationName,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'retries': 0,
    };
    
    _offlineQueue.add(operation);
    await _saveOfflineQueue();
    
    debugPrint('Queued operation: $operationName');
    
    await _analytics.trackEvent('operation_queued', {
      'operation': operationName,
      'queue_size': _offlineQueue.length,
    });
  }

  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    debugPrint('Processing ${_offlineQueue.length} queued operations');
    
    final operationsToProcess = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();
    
    int successCount = 0;
    int failCount = 0;
    
    for (final operation in operationsToProcess) {
      try {
        await _executeQueuedOperation(operation);
        successCount++;
      } catch (e) {
        failCount++;
        operation['retries'] = (operation['retries'] ?? 0) + 1;
        
        // Re-queue if not too many retries
        if (operation['retries'] < _maxRetries) {
          _offlineQueue.add(operation);
        } else {
          await _analytics.recordError(e, StackTrace.current, 'queued_operation_failed', {
            'operation': operation['operation'],
            'retries': operation['retries'],
          });
        }
      }
    }
    
    await _saveOfflineQueue();
    
    await _analytics.trackEvent('offline_queue_processed', {
      'success_count': successCount,
      'fail_count': failCount,
      'remaining_count': _offlineQueue.length,
    });
  }

  Future<void> _executeQueuedOperation(Map<String, dynamic> operation) async {
    final operationName = operation['operation'] as String;
    final data = operation['data'] as Map<String, dynamic>;
    
    switch (operationName) {
      case 'sync_product':
        // Execute product sync
        break;
      case 'sync_sale':
        // Execute sale sync
        break;
      case 'backup_data':
        // Execute backup
        break;
      default:
        debugPrint('Unknown queued operation: $operationName');
    }
  }

  Future<void> _saveOfflineQueue() async {
    try {
      await _localStorage.setSetting('offline_queue', json.encode(_offlineQueue));
    } catch (e) {
      debugPrint('Failed to save offline queue: $e');
    }
  }

  Future<void> _loadOfflineQueue() async {
    try {
      final queueJson = _localStorage.getSetting<String>('offline_queue');
      if (queueJson != null) {
        final queue = json.decode(queueJson) as List;
        _offlineQueue.addAll(queue.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Failed to load offline queue: $e');
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isOfflineMode && _offlineQueue.isNotEmpty) {
        _processOfflineQueue();
      }
    });
  }

  // Specific Fallback Implementations
  Future<String> getAlternativeProductData(String productId) async {
    // Fallback to local cache or default values
    try {
      final cachedData = _localStorage.getSetting<String>('cached_product_$productId');
      if (cachedData != null) {
        return cachedData;
      }
      
      // Return minimal product data
      return json.encode({
        'id': productId,
        'name': 'Unknown Product',
        'price': 0.0,
        'stock': 0,
        'source': 'fallback',
      });
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'product_fallback_failed');
      rethrow;
    }
  }

  Future<bool> performOfflineSync() async {
    // Implement offline-first sync logic
    try {
      // Collect all unsynced data
      final unsyncedProducts = _localStorage.getUnsyncedProducts();
      final unsyncedSales = _localStorage.getUnsyncedSales();
      
      // Store for later sync
      for (final product in unsyncedProducts) {
        await _queueOperation('sync_product', product.toMap());
      }
      
      for (final sale in unsyncedSales) {
        await _queueOperation('sync_sale', sale.toMap());
      }
      
      return true;
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'offline_sync_failed');
      return false;
    }
  }

  Future<void> enableGracefulDegradation() async {
    // Reduce functionality to essential features only
    await _analytics.trackEvent('graceful_degradation_enabled', {
      'offline_mode': _isOfflineMode,
      'degraded_services': _getDegradedServices(),
    });
    
    // Disable non-essential features
    _isSyncDegraded = true;
    
    // Show user notification about degraded mode
    // This would be handled by UI layer
  }

  List<String> _getDegradedServices() {
    final degraded = <String>[];
    if (_isFirebaseDegraded) degraded.add('firebase');
    if (_isCameraDegraded) degraded.add('camera');
    if (_isSyncDegraded) degraded.add('sync');
    return degraded;
  }

  // Health Check
  Future<Map<String, dynamic>> getSystemHealth() async {
    final health = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'offline_mode': _isOfflineMode,
      'degraded_services': _getDegradedServices(),
      'queued_operations': _offlineQueue.length,
      'error_counts': Map<String, int>.from(_errorCounts),
      'platform': PlatformUtils.getPlatformName(),
    };
    
    // Check service availability
    health['services'] = {
      'local_storage': await _checkLocalStorage(),
      'network': !_isOfflineMode,
      'camera': !_isCameraDegraded && PlatformUtils.supportsBarcodeScanning,
      'firebase': !_isFirebaseDegraded,
    };
    
    return health;
  }

  Future<bool> _checkLocalStorage() async {
    try {
      await _localStorage.setSetting('health_check', DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Error Recovery
  Future<void> attemptRecovery() async {
    debugPrint('Attempting system recovery...');
    
    try {
      // Reset error states
      await _resetDegradedServices();
      
      // Check connectivity
      await _checkConnectivity();
      
      // Process any queued operations
      if (!_isOfflineMode) {
        await _processOfflineQueue();
      }
      
      await _analytics.trackEvent('recovery_attempted', {
        'success': true,
        'offline_mode': _isOfflineMode,
      });
      
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'recovery_failed');
    }
  }

  // Cleanup
  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _saveOfflineQueue();
  }
}