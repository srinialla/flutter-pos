import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/sale.dart';
import 'local_storage_service.dart';
import 'auth_service.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AuthService _auth = AuthService.instance;
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Get device ID for conflict resolution
  String get deviceId {
    // You might want to use device_info_plus to get actual device ID
    return _auth.currentUserId ?? 'unknown_device';
  }

  // Full sync - both directions
  Future<SyncResult> sync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    if (!await isOnline()) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
      );
    }

    if (!_auth.isLoggedIn) {
      return SyncResult(
        success: false,
        message: 'User not authenticated',
      );
    }

    _isSyncing = true;
    
    try {
      final results = await Future.wait([
        _syncProducts(),
        _syncSales(),
      ]);

      final productResult = results[0] as SyncResult;
      final saleResult = results[1] as SyncResult;

      _lastSyncTime = DateTime.now();
      await _localStorage.setSetting('lastSyncTime', _lastSyncTime!.millisecondsSinceEpoch);

      final success = productResult.success && saleResult.success;
      
      return SyncResult(
        success: success,
        message: success 
          ? 'Sync completed successfully'
          : 'Sync completed with errors: ${productResult.message}, ${saleResult.message}',
        productsUploaded: productResult.productsUploaded,
        productsDownloaded: productResult.productsDownloaded,
        salesUploaded: saleResult.salesUploaded,
        salesDownloaded: saleResult.salesDownloaded,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }

  // Sync products
  Future<SyncResult> _syncProducts() async {
    int uploaded = 0;
    int downloaded = 0;

    try {
      final userId = _auth.currentUserId!;
      final productsRef = _firestore.collection('users').doc(userId).collection('products');

      // Upload local changes
      final unsyncedProducts = _localStorage.getUnsyncedProducts();
      for (final product in unsyncedProducts) {
        product.deviceId = deviceId;
        
        if (product.isDeleted) {
          await productsRef.doc(product.id).delete();
        } else {
          await productsRef.doc(product.id).set(product.toMap());
        }
        
        await _localStorage.markProductAsSynced(product.id);
        uploaded++;
      }

      // Download remote changes
      final lastSync = _localStorage.getSetting<int>('lastProductSync', defaultValue: 0);
      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);

      final query = productsRef.where('updatedAt', isGreaterThan: lastSyncTime.millisecondsSinceEpoch);
      final snapshot = await query.get();

      for (final doc in snapshot.docs) {
        final remoteProduct = Product.fromMap(doc.data());
        final localProduct = _localStorage.getProduct(remoteProduct.id);

        if (localProduct == null) {
          // New product from remote
          remoteProduct.isSynced = true;
          await _localStorage.addProduct(remoteProduct);
          downloaded++;
        } else {
          // Conflict resolution - latest timestamp wins
          if (remoteProduct.updatedAt.isAfter(localProduct.updatedAt)) {
            remoteProduct.isSynced = true;
            await _localStorage.updateProduct(remoteProduct);
            downloaded++;
          }
        }
      }

      await _localStorage.setSetting('lastProductSync', DateTime.now().millisecondsSinceEpoch);

      return SyncResult(
        success: true,
        message: 'Products synced successfully',
        productsUploaded: uploaded,
        productsDownloaded: downloaded,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Product sync failed: $e',
      );
    }
  }

  // Sync sales
  Future<SyncResult> _syncSales() async {
    int uploaded = 0;
    int downloaded = 0;

    try {
      final userId = _auth.currentUserId!;
      final salesRef = _firestore.collection('users').doc(userId).collection('sales');

      // Upload local changes
      final unsyncedSales = _localStorage.getUnsyncedSales();
      for (final sale in unsyncedSales) {
        sale.deviceId = deviceId;
        await salesRef.doc(sale.id).set(sale.toMap());
        await _localStorage.markSaleAsSynced(sale.id);
        uploaded++;
      }

      // Download remote changes
      final lastSync = _localStorage.getSetting<int>('lastSaleSync', defaultValue: 0);
      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);

      final query = salesRef.where('createdAt', isGreaterThan: lastSyncTime.millisecondsSinceEpoch);
      final snapshot = await query.get();

      for (final doc in snapshot.docs) {
        final remoteSale = Sale.fromMap(doc.data());
        final localSale = _localStorage.getSale(remoteSale.id);

        if (localSale == null) {
          // New sale from remote
          remoteSale.isSynced = true;
          await _localStorage.addSale(remoteSale);
          downloaded++;
        }
        // Sales are immutable, so no conflict resolution needed
      }

      await _localStorage.setSetting('lastSaleSync', DateTime.now().millisecondsSinceEpoch);

      return SyncResult(
        success: true,
        message: 'Sales synced successfully',
        salesUploaded: uploaded,
        salesDownloaded: downloaded,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sales sync failed: $e',
      );
    }
  }

  // Upload specific product
  Future<bool> uploadProduct(Product product) async {
    if (!await isOnline() || !_auth.isLoggedIn) return false;

    try {
      final userId = _auth.currentUserId!;
      final productRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .doc(product.id);

      product.deviceId = deviceId;
      
      if (product.isDeleted) {
        await productRef.delete();
      } else {
        await productRef.set(product.toMap());
      }

      await _localStorage.markProductAsSynced(product.id);
      return true;
    } catch (e) {
      debugPrint('Upload product error: $e');
      return false;
    }
  }

  // Upload specific sale
  Future<bool> uploadSale(Sale sale) async {
    if (!await isOnline() || !_auth.isLoggedIn) return false;

    try {
      final userId = _auth.currentUserId!;
      final saleRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('sales')
          .doc(sale.id);

      sale.deviceId = deviceId;
      await saleRef.set(sale.toMap());
      await _localStorage.markSaleAsSynced(sale.id);
      return true;
    } catch (e) {
      debugPrint('Upload sale error: $e');
      return false;
    }
  }

  // Get sync status
  SyncStatus getSyncStatus() {
    final unsyncedProducts = _localStorage.getUnsyncedProducts().length;
    final unsyncedSales = _localStorage.getUnsyncedSales().length;
    final totalUnsynced = unsyncedProducts + unsyncedSales;

    return SyncStatus(
      hasUnsyncedData: totalUnsynced > 0,
      unsyncedProducts: unsyncedProducts,
      unsyncedSales: unsyncedSales,
      lastSyncTime: _lastSyncTime,
      isOnline: false, // Will be updated by connectivity stream
    );
  }

  // Listen to connectivity changes
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }

  // Auto sync when coming online
  void startAutoSync() {
    connectivityStream.listen((isOnline) async {
      if (isOnline && !_isSyncing) {
        final unsyncedCount = _localStorage.getUnsyncedProducts().length + 
                             _localStorage.getUnsyncedSales().length;
        
        if (unsyncedCount > 0) {
          debugPrint('Auto-syncing $unsyncedCount unsynced items');
          await sync();
        }
      }
    });
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int productsUploaded;
  final int productsDownloaded;
  final int salesUploaded;
  final int salesDownloaded;

  SyncResult({
    required this.success,
    required this.message,
    this.productsUploaded = 0,
    this.productsDownloaded = 0,
    this.salesUploaded = 0,
    this.salesDownloaded = 0,
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, message: $message, '
           'products: ↑$productsUploaded ↓$productsDownloaded, '
           'sales: ↑$salesUploaded ↓$salesDownloaded)';
  }
}

class SyncStatus {
  final bool hasUnsyncedData;
  final int unsyncedProducts;
  final int unsyncedSales;
  final DateTime? lastSyncTime;
  final bool isOnline;

  SyncStatus({
    required this.hasUnsyncedData,
    required this.unsyncedProducts,
    required this.unsyncedSales,
    this.lastSyncTime,
    required this.isOnline,
  });
}