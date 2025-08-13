import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService.instance;
  
  bool _isOnline = false;
  bool _hasUnsyncedData = false;
  int _unsyncedProducts = 0;
  int _unsyncedSales = 0;
  DateTime? _lastSyncTime;
  String? _lastSyncError;
  bool _autoSync = true;

  bool get isOnline => _isOnline;
  bool get isSyncing => _syncService.isSyncing;
  bool get hasUnsyncedData => _hasUnsyncedData;
  int get unsyncedProducts => _unsyncedProducts;
  int get unsyncedSales => _unsyncedSales;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  bool get autoSync => _autoSync;

  SyncProvider() {
    _initializeSync();
  }

  void _initializeSync() {
    // Listen to connectivity changes
    _syncService.connectivityStream.listen((isOnline) {
      _isOnline = isOnline;
      notifyListeners();
      
      // Auto sync when coming online
      if (isOnline && _autoSync && _hasUnsyncedData && !_syncService.isSyncing) {
        sync();
      }
    });

    // Update sync status periodically
    _updateSyncStatus();
  }

  void _updateSyncStatus() {
    final status = _syncService.getSyncStatus();
    _hasUnsyncedData = status.hasUnsyncedData;
    _unsyncedProducts = status.unsyncedProducts;
    _unsyncedSales = status.unsyncedSales;
    _lastSyncTime = status.lastSyncTime;
    notifyListeners();
  }

  Future<bool> sync() async {
    if (_syncService.isSyncing) return false;
    
    _lastSyncError = null;
    notifyListeners();

    try {
      final result = await _syncService.sync();
      
      if (result.success) {
        _lastSyncTime = DateTime.now();
        _lastSyncError = null;
      } else {
        _lastSyncError = result.message;
      }
      
      _updateSyncStatus();
      return result.success;
    } catch (e) {
      _lastSyncError = 'Sync failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> checkConnectivity() async {
    _isOnline = await _syncService.isOnline();
    notifyListeners();
  }

  void setAutoSync(bool enabled) {
    _autoSync = enabled;
    notifyListeners();
  }

  void clearSyncError() {
    _lastSyncError = null;
    notifyListeners();
  }

  String getSyncStatusText() {
    if (_syncService.isSyncing) {
      return 'Syncing...';
    }
    
    if (!_isOnline) {
      return 'Offline';
    }
    
    if (_hasUnsyncedData) {
      return 'Has unsynced data';
    }
    
    if (_lastSyncTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastSyncTime!);
      
      if (diff.inMinutes < 1) {
        return 'Synced just now';
      } else if (diff.inHours < 1) {
        return 'Synced ${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        return 'Synced ${diff.inHours}h ago';
      } else {
        return 'Synced ${diff.inDays}d ago';
      }
    }
    
    return 'Not synced';
  }

  String getUnsyncedDataText() {
    if (!_hasUnsyncedData) return '';
    
    final parts = <String>[];
    if (_unsyncedProducts > 0) {
      parts.add('$_unsyncedProducts product${_unsyncedProducts > 1 ? 's' : ''}');
    }
    if (_unsyncedSales > 0) {
      parts.add('$_unsyncedSales sale${_unsyncedSales > 1 ? 's' : ''}');
    }
    
    return parts.join(', ');
  }
}