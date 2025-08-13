import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../utils/platform_utils.dart';
import 'local_storage_service.dart';
import 'auth_service.dart';
import 'security_service.dart';

class BackupService {
  static BackupService? _instance;
  static BackupService get instance => _instance ??= BackupService._();
  BackupService._();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AuthService _authService = AuthService.instance;
  final SecurityService _securityService = SecurityService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Backup configuration
  static const String backupVersion = '1.0';
  static const Duration autoBackupInterval = Duration(hours: 24);
  static const int maxBackupRetention = 30; // days

  // Backup types
  enum BackupType {
    full,
    incremental,
    critical,
  }

  // Backup destinations
  enum BackupDestination {
    local,
    cloud,
    both,
  }

  Future<BackupResult> createBackup({
    BackupType type = BackupType.full,
    BackupDestination destination = BackupDestination.both,
    String? customPath,
  }) async {
    try {
      final backupData = await _prepareBackupData(type);
      
      if (backupData.isEmpty) {
        return BackupResult(
          success: false,
          message: 'No data to backup',
        );
      }

      final results = <String, bool>{};
      
      if (destination == BackupDestination.local || destination == BackupDestination.both) {
        final localResult = await _createLocalBackup(backupData, customPath);
        results['local'] = localResult.success;
      }
      
      if (destination == BackupDestination.cloud || destination == BackupDestination.both) {
        final cloudResult = await _createCloudBackup(backupData);
        results['cloud'] = cloudResult.success;
      }
      
      final success = results.values.any((result) => result);
      
      if (success) {
        await _updateBackupMetadata(type, destination);
      }
      
      return BackupResult(
        success: success,
        message: success ? 'Backup created successfully' : 'Backup failed',
        metadata: {
          'type': type.toString(),
          'destination': destination.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'results': results,
        },
      );
    } catch (e) {
      debugPrint('Backup creation failed: $e');
      return BackupResult(
        success: false,
        message: 'Backup failed: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _prepareBackupData(BackupType type) async {
    final data = <String, dynamic>{
      'version': backupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type.toString(),
      'device_id': _securityService.deviceId,
      'user_id': _authService.currentUserId,
    };

    switch (type) {
      case BackupType.full:
        data['products'] = await _exportProducts();
        data['sales'] = await _exportSales();
        data['settings'] = await _exportSettings();
        break;
        
      case BackupType.incremental:
        final lastBackup = await _getLastBackupTime();
        data['products'] = await _exportProductsAfter(lastBackup);
        data['sales'] = await _exportSalesAfter(lastBackup);
        data['settings'] = await _exportSettings();
        break;
        
      case BackupType.critical:
        data['sales'] = await _exportSales();
        data['critical_settings'] = await _exportCriticalSettings();
        break;
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> _exportProducts() async {
    final products = _localStorage.getAllProducts(includeDeleted: true);
    return products.map((product) => product.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportProductsAfter(DateTime? after) async {
    if (after == null) return _exportProducts();
    
    final products = _localStorage.getAllProducts(includeDeleted: true);
    final filtered = products.where((product) => 
        product.updatedAt.isAfter(after)).toList();
    
    return filtered.map((product) => product.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSales() async {
    final sales = _localStorage.getAllSales();
    return sales.map((sale) => sale.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportSalesAfter(DateTime? after) async {
    if (after == null) return _exportSales();
    
    final sales = _localStorage.getAllSales();
    final filtered = sales.where((sale) => 
        sale.createdAt.isAfter(after)).toList();
    
    return filtered.map((sale) => sale.toMap()).toList();
  }

  Future<Map<String, dynamic>> _exportSettings() async {
    // Export non-sensitive settings
    return {
      'tax_rate': _localStorage.getSetting<double>('taxRate'),
      'business_name': _localStorage.getSetting<String>('businessName'),
      'currency': _localStorage.getSetting<String>('currency'),
      'theme_mode': _localStorage.getSetting<int>('theme_mode'),
      'auto_sync': _localStorage.getSetting<bool>('autoSync'),
    };
  }

  Future<Map<String, dynamic>> _exportCriticalSettings() async {
    return {
      'tax_rate': _localStorage.getSetting<double>('taxRate'),
      'business_name': _localStorage.getSetting<String>('businessName'),
    };
  }

  Future<BackupResult> _createLocalBackup(
    Map<String, dynamic> data, 
    String? customPath,
  ) async {
    try {
      if (PlatformUtils.isWeb) {
        return await _createWebBackup(data);
      }
      
      final backupJson = json.encode(data);
      final compressed = await _compressData(backupJson);
      final encrypted = _securityService.encryptData(compressed);
      
      final directory = customPath != null 
          ? Directory(customPath)
          : await _getBackupDirectory();
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'pos_backup_$timestamp.pbk';
      final file = File('${directory.path}/$filename');
      
      await file.writeAsString(encrypted);
      
      // Create checksum
      final checksum = _generateChecksum(encrypted);
      final checksumFile = File('${directory.path}/$filename.checksum');
      await checksumFile.writeAsString(checksum);
      
      return BackupResult(
        success: true,
        message: 'Local backup created successfully',
        metadata: {'path': file.path, 'size': encrypted.length},
      );
    } catch (e) {
      debugPrint('Local backup failed: $e');
      return BackupResult(
        success: false,
        message: 'Local backup failed: $e',
      );
    }
  }

  Future<BackupResult> _createWebBackup(Map<String, dynamic> data) async {
    try {
      final backupJson = json.encode(data);
      final compressed = await _compressData(backupJson);
      final bytes = Uint8List.fromList(utf8.encode(compressed));
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'pos_backup_$timestamp.json';
      
      // For web, we'll store in local storage and provide download
      await _localStorage.setSetting('latest_backup', compressed);
      
      return BackupResult(
        success: true,
        message: 'Web backup prepared successfully',
        metadata: {
          'filename': filename,
          'size': bytes.length,
          'download_ready': true,
        },
      );
    } catch (e) {
      debugPrint('Web backup failed: $e');
      return BackupResult(
        success: false,
        message: 'Web backup failed: $e',
      );
    }
  }

  Future<BackupResult> _createCloudBackup(Map<String, dynamic> data) async {
    try {
      if (!_authService.isLoggedIn) {
        return BackupResult(
          success: false,
          message: 'User not authenticated for cloud backup',
        );
      }

      final userId = _authService.currentUserId!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Compress and encrypt data
      final backupJson = json.encode(data);
      final compressed = await _compressData(backupJson);
      final encrypted = _securityService.encryptData(compressed);
      
      // Store in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .doc(timestamp.toString())
          .set({
        'data': encrypted,
        'timestamp': FieldValue.serverTimestamp(),
        'type': data['type'],
        'checksum': _generateChecksum(encrypted),
        'version': backupVersion,
      });

      // Clean old backups
      await _cleanOldCloudBackups(userId);

      return BackupResult(
        success: true,
        message: 'Cloud backup created successfully',
        metadata: {'timestamp': timestamp, 'size': encrypted.length},
      );
    } catch (e) {
      debugPrint('Cloud backup failed: $e');
      return BackupResult(
        success: false,
        message: 'Cloud backup failed: $e',
      );
    }
  }

  Future<RestoreResult> restoreFromBackup({
    String? backupPath,
    bool fromCloud = false,
    DateTime? specificBackup,
  }) async {
    try {
      Map<String, dynamic> backupData;
      
      if (fromCloud) {
        backupData = await _loadCloudBackup(specificBackup);
      } else {
        backupData = await _loadLocalBackup(backupPath);
      }
      
      // Validate backup
      if (!await _validateBackup(backupData)) {
        return RestoreResult(
          success: false,
          message: 'Invalid or corrupted backup data',
        );
      }
      
      // Create pre-restore backup
      await createBackup(
        type: BackupType.full,
        destination: BackupDestination.local,
      );
      
      // Restore data
      final result = await _performRestore(backupData);
      
      if (result.success) {
        await _updateRestoreMetadata();
      }
      
      return result;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return RestoreResult(
        success: false,
        message: 'Restore failed: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _loadLocalBackup(String? filePath) async {
    String path;
    
    if (filePath != null) {
      path = filePath;
    } else {
      if (PlatformUtils.isWeb) {
        // For web, load from local storage
        final backup = _localStorage.getSetting<String>('latest_backup');
        if (backup == null) {
          throw Exception('No backup found in browser storage');
        }
        return json.decode(backup);
      }
      
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pbk'],
      );
      
      if (result?.files.single.path == null) {
        throw Exception('No backup file selected');
      }
      
      path = result!.files.single.path!;
    }
    
    final file = File(path);
    final encrypted = await file.readAsString();
    
    // Verify checksum if available
    final checksumFile = File('$path.checksum');
    if (await checksumFile.exists()) {
      final expectedChecksum = await checksumFile.readAsString();
      final actualChecksum = _generateChecksum(encrypted);
      
      if (expectedChecksum != actualChecksum) {
        throw Exception('Backup file integrity check failed');
      }
    }
    
    final decrypted = _securityService.decryptData(encrypted);
    final decompressed = await _decompressData(decrypted);
    
    return json.decode(decompressed);
  }

  Future<Map<String, dynamic>> _loadCloudBackup(DateTime? specific) async {
    if (!_authService.isLoggedIn) {
      throw Exception('User not authenticated');
    }

    final userId = _authService.currentUserId!;
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('backups')
        .orderBy('timestamp', descending: true);

    if (specific != null) {
      query = query.where('timestamp', 
          isEqualTo: Timestamp.fromDate(specific));
    }

    final snapshot = await query.limit(1).get();
    
    if (snapshot.docs.isEmpty) {
      throw Exception('No cloud backup found');
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    
    final encrypted = data['data'] as String;
    final checksum = data['checksum'] as String;
    
    // Verify integrity
    if (_generateChecksum(encrypted) != checksum) {
      throw Exception('Cloud backup integrity check failed');
    }
    
    final decrypted = _securityService.decryptData(encrypted);
    final decompressed = await _decompressData(decrypted);
    
    return json.decode(decompressed);
  }

  Future<bool> _validateBackup(Map<String, dynamic> data) async {
    try {
      // Check required fields
      if (!data.containsKey('version') || 
          !data.containsKey('timestamp') ||
          !data.containsKey('user_id')) {
        return false;
      }
      
      // Validate version compatibility
      final version = data['version'] as String;
      if (!_isVersionCompatible(version)) {
        debugPrint('Backup version $version not compatible');
        return false;
      }
      
      // Validate user
      final backupUserId = data['user_id'];
      if (backupUserId != _authService.currentUserId) {
        debugPrint('Backup user ID mismatch');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Backup validation failed: $e');
      return false;
    }
  }

  bool _isVersionCompatible(String version) {
    // Simple version compatibility check
    final backupMajor = int.parse(version.split('.')[0]);
    final currentMajor = int.parse(backupVersion.split('.')[0]);
    
    return backupMajor <= currentMajor;
  }

  Future<RestoreResult> _performRestore(Map<String, dynamic> data) async {
    try {
      int itemsRestored = 0;
      
      // Restore products
      if (data.containsKey('products')) {
        final products = data['products'] as List;
        for (final productData in products) {
          final product = Product.fromMap(productData);
          await _localStorage.addProduct(product);
          itemsRestored++;
        }
      }
      
      // Restore sales
      if (data.containsKey('sales')) {
        final sales = data['sales'] as List;
        for (final saleData in sales) {
          final sale = Sale.fromMap(saleData);
          await _localStorage.addSale(sale);
          itemsRestored++;
        }
      }
      
      // Restore settings
      if (data.containsKey('settings')) {
        final settings = data['settings'] as Map<String, dynamic>;
        for (final entry in settings.entries) {
          if (entry.value != null) {
            await _localStorage.setSetting(entry.key, entry.value);
          }
        }
      }
      
      return RestoreResult(
        success: true,
        message: 'Restore completed successfully',
        itemsRestored: itemsRestored,
      );
    } catch (e) {
      debugPrint('Restore operation failed: $e');
      return RestoreResult(
        success: false,
        message: 'Restore failed: $e',
      );
    }
  }

  // Utility methods
  Future<Directory> _getBackupDirectory() async {
    if (PlatformUtils.isDesktop) {
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${documentsDir.path}/POS_Backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      return backupDir;
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<String> _compressData(String data) async {
    // Simple compression using gzip
    final bytes = utf8.encode(data);
    final compressed = gzip.encode(bytes);
    return base64Encode(compressed);
  }

  Future<String> _decompressData(String compressedData) async {
    final bytes = base64Decode(compressedData);
    final decompressed = gzip.decode(bytes);
    return utf8.decode(decompressed);
  }

  String _generateChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<DateTime?> _getLastBackupTime() async {
    final timestamp = _localStorage.getSetting<int>('lastBackupTime');
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  Future<void> _updateBackupMetadata(
    BackupType type, 
    BackupDestination destination,
  ) async {
    await _localStorage.setSetting('lastBackupTime', 
        DateTime.now().millisecondsSinceEpoch);
    await _localStorage.setSetting('lastBackupType', type.toString());
    await _localStorage.setSetting('lastBackupDestination', 
        destination.toString());
  }

  Future<void> _updateRestoreMetadata() async {
    await _localStorage.setSetting('lastRestoreTime', 
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _cleanOldCloudBackups(String userId) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(const Duration(days: maxBackupRetention));
      
      final query = _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate));
      
      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      debugPrint('Cleaned ${snapshot.docs.length} old backups');
    } catch (e) {
      debugPrint('Failed to clean old backups: $e');
    }
  }

  // Auto backup
  Future<void> scheduleAutoBackup() async {
    if (!_shouldPerformAutoBackup()) return;
    
    debugPrint('Performing scheduled auto backup');
    
    await createBackup(
      type: BackupType.incremental,
      destination: BackupDestination.cloud,
    );
  }

  bool _shouldPerformAutoBackup() {
    final lastBackup = _getLastBackupTime();
    if (lastBackup == null) return true;
    
    final timeSinceLastBackup = DateTime.now().difference(lastBackup as DateTime);
    return timeSinceLastBackup >= autoBackupInterval;
  }

  // Backup listing
  Future<List<BackupInfo>> getAvailableBackups({
    bool includeCloud = true,
    bool includeLocal = true,
  }) async {
    final backups = <BackupInfo>[];
    
    if (includeLocal) {
      final localBackups = await _getLocalBackups();
      backups.addAll(localBackups);
    }
    
    if (includeCloud && _authService.isLoggedIn) {
      final cloudBackups = await _getCloudBackups();
      backups.addAll(cloudBackups);
    }
    
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  Future<List<BackupInfo>> _getLocalBackups() async {
    final backups = <BackupInfo>[];
    
    try {
      if (PlatformUtils.isWeb) {
        final backup = _localStorage.getSetting<String>('latest_backup');
        if (backup != null) {
          backups.add(BackupInfo(
            timestamp: DateTime.now(),
            type: BackupType.full,
            destination: BackupDestination.local,
            size: backup.length,
            isLocal: true,
          ));
        }
        return backups;
      }
      
      final directory = await _getBackupDirectory();
      final files = directory.listSync()
          .where((file) => file.path.endsWith('.pbk'))
          .cast<File>();
      
      for (final file in files) {
        final stat = await file.stat();
        backups.add(BackupInfo(
          timestamp: stat.modified,
          type: BackupType.full, // Simplified
          destination: BackupDestination.local,
          size: stat.size,
          path: file.path,
          isLocal: true,
        ));
      }
    } catch (e) {
      debugPrint('Failed to get local backups: $e');
    }
    
    return backups;
  }

  Future<List<BackupInfo>> _getCloudBackups() async {
    final backups = <BackupInfo>[];
    
    try {
      final userId = _authService.currentUserId!;
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .orderBy('timestamp', descending: true)
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final typeString = data['type'] as String;
        final type = BackupType.values.firstWhere(
          (t) => t.toString() == typeString,
          orElse: () => BackupType.full,
        );
        
        backups.add(BackupInfo(
          timestamp: timestamp,
          type: type,
          destination: BackupDestination.cloud,
          size: (data['data'] as String).length,
          isLocal: false,
          cloudId: doc.id,
        ));
      }
    } catch (e) {
      debugPrint('Failed to get cloud backups: $e');
    }
    
    return backups;
  }
}

class BackupResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? metadata;

  BackupResult({
    required this.success,
    required this.message,
    this.metadata,
  });
}

class RestoreResult {
  final bool success;
  final String message;
  final int itemsRestored;

  RestoreResult({
    required this.success,
    required this.message,
    this.itemsRestored = 0,
  });
}

class BackupInfo {
  final DateTime timestamp;
  final BackupType type;
  final BackupDestination destination;
  final int size;
  final String? path;
  final String? cloudId;
  final bool isLocal;

  BackupInfo({
    required this.timestamp,
    required this.type,
    required this.destination,
    required this.size,
    this.path,
    this.cloudId,
    required this.isLocal,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}