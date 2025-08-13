import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';
import '../models/receipt_config.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

class TeamSyncService {
  static TeamSyncService? _instance;
  static TeamSyncService get instance => _instance ??= TeamSyncService._();
  TeamSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final NotificationService _notifications = NotificationService.instance;

  StreamSubscription<QuerySnapshot>? _teamDataSubscription;
  StreamSubscription<DocumentSnapshot>? _userPresenceSubscription;
  Timer? _presenceUpdateTimer;
  Timer? _conflictResolutionTimer;

  bool _isInitialized = false;
  String? _currentUserId;
  String? _businessId;
  TeamMember? _currentUser;
  List<TeamMember> _teamMembers = [];
  Map<String, DateTime> _lastSyncTimestamps = {};

  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;
  String? get businessId => _businessId;
  TeamMember? get currentUser => _currentUser;
  List<TeamMember> get teamMembers => List.unmodifiable(_teamMembers);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = user.uid;
      
      // Load business configuration
      await _loadBusinessConfiguration();
      
      // Load current user profile
      await _loadCurrentUserProfile();
      
      // Start team synchronization
      await _startTeamSync();
      
      // Start presence tracking
      await _startPresenceTracking();
      
      // Start conflict resolution monitoring
      _startConflictResolution();

      _isInitialized = true;
      debugPrint('Team sync service initialized');

      await _analytics.trackEvent('team_sync_initialized', {
        'user_id': _currentUserId,
        'business_id': _businessId,
        'user_role': _currentUser?.role.toString(),
      });
    } catch (e) {
      debugPrint('Team sync initialization failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'team_sync_init_failed');
    }
  }

  Future<void> _loadBusinessConfiguration() async {
    // Try to get business ID from local storage first
    _businessId = _localStorage.getSetting<String>('business_id');
    
    if (_businessId == null) {
      // Create or join business - this would typically be done during onboarding
      await _createOrJoinBusiness();
    }
  }

  Future<void> _createOrJoinBusiness() async {
    // For this implementation, create a default business
    // In a real app, this would be part of the onboarding flow
    _businessId = 'business_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
    await _localStorage.setSetting('business_id', _businessId);
    
    // Create business document in Firestore
    await _firestore.collection('businesses').doc(_businessId).set({
      'id': _businessId,
      'name': 'My Business',
      'ownerId': _currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'settings': {
        'allowMultipleLocations': false,
        'requireApprovalForPurchaseOrders': true,
        'enableRealTimeSync': true,
        'conflictResolutionStrategy': 'last_write_wins',
      },
    });
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final userDoc = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('team_members')
          .doc(_currentUserId)
          .get();

      if (userDoc.exists) {
        _currentUser = TeamMember.fromMap(userDoc.data()!);
      } else {
        // Create default user profile
        _currentUser = TeamMember(
          id: _currentUserId!,
          email: _auth.currentUser?.email ?? '',
          name: _auth.currentUser?.displayName ?? 'User',
          role: UserRole.manager, // Default to manager for business owner
          permissions: UserRole.manager.defaultPermissions,
          isActive: true,
          joinedAt: DateTime.now(),
        );
        
        await _saveUserProfile(_currentUser!);
      }
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
      // Create fallback profile
      _currentUser = TeamMember(
        id: _currentUserId!,
        email: _auth.currentUser?.email ?? '',
        name: 'User',
        role: UserRole.cashier,
        permissions: UserRole.cashier.defaultPermissions,
        isActive: true,
        joinedAt: DateTime.now(),
      );
    }
  }

  Future<void> _saveUserProfile(TeamMember user) async {
    await _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('team_members')
        .doc(user.id)
        .set(user.toMap());
  }

  Future<void> _startTeamSync() async {
    // Listen to team members changes
    _teamDataSubscription = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('team_members')
        .snapshots()
        .listen(_handleTeamMembersUpdate);
  }

  void _handleTeamMembersUpdate(QuerySnapshot snapshot) {
    try {
      _teamMembers = snapshot.docs
          .map((doc) => TeamMember.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      _analytics.trackEvent('team_members_updated', {
        'member_count': _teamMembers.length,
        'active_members': _teamMembers.where((m) => m.isActive).length,
      });
    } catch (e) {
      debugPrint('Failed to handle team members update: $e');
    }
  }

  Future<void> _startPresenceTracking() async {
    if (_currentUserId == null || _businessId == null) return;

    // Update presence status
    await _updatePresenceStatus(PresenceStatus.online);
    
    // Listen to presence changes
    _userPresenceSubscription = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('presence')
        .doc(_currentUserId)
        .snapshots()
        .listen(_handlePresenceUpdate);

    // Start periodic presence updates
    _presenceUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updatePresenceStatus(PresenceStatus.online),
    );
  }

  void _handlePresenceUpdate(DocumentSnapshot snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      debugPrint('Presence updated: ${data['status']} at ${data['lastSeen']}');
    }
  }

  Future<void> _updatePresenceStatus(PresenceStatus status) async {
    if (_currentUserId == null || _businessId == null) return;

    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('presence')
          .doc(_currentUserId)
          .set({
        'userId': _currentUserId,
        'status': status.toString(),
        'lastSeen': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': defaultTargetPlatform.toString(),
          'userAgent': 'POS App',
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update presence: $e');
    }
  }

  void _startConflictResolution() {
    _conflictResolutionTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _resolveDataConflicts(),
    );
  }

  // Data Synchronization Methods
  Future<void> syncData({bool forceFullSync = false}) async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        _syncProducts(forceFullSync),
        _syncSales(forceFullSync),
        _syncCustomers(forceFullSync),
        _syncSuppliers(forceFullSync),
        _syncPurchaseOrders(forceFullSync),
        _syncReceiptConfigs(forceFullSync),
      ]);

      await _analytics.trackEvent('data_sync_completed', {
        'force_full_sync': forceFullSync,
        'sync_timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Data sync failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'data_sync_failed');
    }
  }

  Future<void> _syncProducts(bool forceFullSync) async {
    try {
      final lastSync = forceFullSync ? null : _lastSyncTimestamps['products'];
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('products');

      if (lastSync != null) {
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        final product = Product.fromMap(doc.data() as Map<String, dynamic>);
        await _localStorage.saveProduct(product);
      }

      _lastSyncTimestamps['products'] = DateTime.now();
      debugPrint('Synced ${snapshot.docs.length} products');
    } catch (e) {
      debugPrint('Product sync failed: $e');
    }
  }

  Future<void> _syncSales(bool forceFullSync) async {
    try {
      final lastSync = forceFullSync ? null : _lastSyncTimestamps['sales'];
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('sales');

      if (lastSync != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        final sale = Sale.fromMap(doc.data() as Map<String, dynamic>);
        await _localStorage.saveSale(sale);
      }

      _lastSyncTimestamps['sales'] = DateTime.now();
      debugPrint('Synced ${snapshot.docs.length} sales');
    } catch (e) {
      debugPrint('Sales sync failed: $e');
    }
  }

  Future<void> _syncCustomers(bool forceFullSync) async {
    try {
      final lastSync = forceFullSync ? null : _lastSyncTimestamps['customers'];
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('customers');

      if (lastSync != null) {
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        final customer = Customer.fromMap(doc.data() as Map<String, dynamic>);
        await _saveCustomerToLocal(customer);
      }

      _lastSyncTimestamps['customers'] = DateTime.now();
      debugPrint('Synced ${snapshot.docs.length} customers');
    } catch (e) {
      debugPrint('Customers sync failed: $e');
    }
  }

  Future<void> _syncSuppliers(bool forceFullSync) async {
    try {
      final lastSync = forceFullSync ? null : _lastSyncTimestamps['suppliers'];
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('suppliers');

      if (lastSync != null) {
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        final supplier = Supplier.fromMap(doc.data() as Map<String, dynamic>);
        await _saveSupplierToLocal(supplier);
      }

      _lastSyncTimestamps['suppliers'] = DateTime.now();
      debugPrint('Synced ${snapshot.docs.length} suppliers');
    } catch (e) {
      debugPrint('Suppliers sync failed: $e');
    }
  }

  Future<void> _syncPurchaseOrders(bool forceFullSync) async {
    try {
      final lastSync = forceFullSync ? null : _lastSyncTimestamps['purchase_orders'];
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('purchase_orders');

      if (lastSync != null) {
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        final order = PurchaseOrder.fromMap(doc.data() as Map<String, dynamic>);
        await _savePurchaseOrderToLocal(order);
      }

      _lastSyncTimestamps['purchase_orders'] = DateTime.now();
      debugPrint('Synced ${snapshot.docs.length} purchase orders');
    } catch (e) {
      debugPrint('Purchase orders sync failed: $e');
    }
  }

  Future<void> _syncReceiptConfigs(bool forceFullSync) async {
    try {
      final lastSync = forceFullSync ? null : _lastSyncTimestamps['receipt_configs'];
      Query query = _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('receipt_configs');

      if (lastSync != null) {
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        final config = ReceiptConfig.fromMap(doc.data() as Map<String, dynamic>);
        await _saveReceiptConfigToLocal(config);
      }

      _lastSyncTimestamps['receipt_configs'] = DateTime.now();
      debugPrint('Synced ${snapshot.docs.length} receipt configs');
    } catch (e) {
      debugPrint('Receipt configs sync failed: $e');
    }
  }

  // Upload local changes to cloud
  Future<void> uploadLocalChanges() async {
    if (!_isInitialized) return;

    try {
      await Future.wait([
        _uploadProducts(),
        _uploadSales(),
        _uploadCustomers(),
        _uploadSuppliers(),
        _uploadPurchaseOrders(),
        _uploadReceiptConfigs(),
      ]);

      await _analytics.trackEvent('local_changes_uploaded', {
        'upload_timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Upload local changes failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'upload_changes_failed');
    }
  }

  Future<void> _uploadProducts() async {
    try {
      final products = _localStorage.getAllProducts()
          .where((p) => !p.isSynced)
          .toList();

      for (final product in products) {
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('products')
            .doc(product.id)
            .set(product.toMap(), SetOptions(merge: true));

        // Mark as synced
        final syncedProduct = product.copyWith(isSynced: true);
        await _localStorage.saveProduct(syncedProduct);
      }

      debugPrint('Uploaded ${products.length} products');
    } catch (e) {
      debugPrint('Product upload failed: $e');
    }
  }

  Future<void> _uploadSales() async {
    try {
      final sales = _localStorage.getAllSales()
          .where((s) => !s.isSynced)
          .toList();

      for (final sale in sales) {
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('sales')
            .doc(sale.id)
            .set(sale.toMap(), SetOptions(merge: true));

        // Mark as synced
        final syncedSale = sale.copyWith(isSynced: true);
        await _localStorage.saveSale(syncedSale);
      }

      debugPrint('Uploaded ${sales.length} sales');
    } catch (e) {
      debugPrint('Sales upload failed: $e');
    }
  }

  Future<void> _uploadCustomers() async {
    try {
      final customers = await _getUnsyncedCustomers();

      for (final customer in customers) {
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('customers')
            .doc(customer.id)
            .set(customer.toMap(), SetOptions(merge: true));

        // Mark as synced
        final syncedCustomer = customer.copyWith(isSynced: true);
        await _saveCustomerToLocal(syncedCustomer);
      }

      debugPrint('Uploaded ${customers.length} customers');
    } catch (e) {
      debugPrint('Customers upload failed: $e');
    }
  }

  Future<void> _uploadSuppliers() async {
    try {
      final suppliers = await _getUnsyncedSuppliers();

      for (final supplier in suppliers) {
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('suppliers')
            .doc(supplier.id)
            .set(supplier.toMap(), SetOptions(merge: true));

        // Mark as synced
        final syncedSupplier = supplier.copyWith(isSynced: true);
        await _saveSupplierToLocal(syncedSupplier);
      }

      debugPrint('Uploaded ${suppliers.length} suppliers');
    } catch (e) {
      debugPrint('Suppliers upload failed: $e');
    }
  }

  Future<void> _uploadPurchaseOrders() async {
    try {
      final orders = await _getUnsyncedPurchaseOrders();

      for (final order in orders) {
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('purchase_orders')
            .doc(order.id)
            .set(order.toMap(), SetOptions(merge: true));

        // Mark as synced
        final syncedOrder = order.copyWith(isSynced: true);
        await _savePurchaseOrderToLocal(syncedOrder);
      }

      debugPrint('Uploaded ${orders.length} purchase orders');
    } catch (e) {
      debugPrint('Purchase orders upload failed: $e');
    }
  }

  Future<void> _uploadReceiptConfigs() async {
    try {
      final configs = await _getUnsyncedReceiptConfigs();

      for (final config in configs) {
        await _firestore
            .collection('businesses')
            .doc(_businessId)
            .collection('receipt_configs')
            .doc(config.id)
            .set(config.toMap(), SetOptions(merge: true));

        // Mark as synced
        final syncedConfig = config.copyWith(isSynced: true);
        await _saveReceiptConfigToLocal(syncedConfig);
      }

      debugPrint('Uploaded ${configs.length} receipt configs');
    } catch (e) {
      debugPrint('Receipt configs upload failed: $e');
    }
  }

  // Conflict Resolution
  Future<void> _resolveDataConflicts() async {
    try {
      // Check for conflicts and resolve them
      await Future.wait([
        _resolveProductConflicts(),
        _resolveSaleConflicts(),
        _resolveCustomerConflicts(),
        _resolveSupplierConflicts(),
        _resolvePurchaseOrderConflicts(),
      ]);
    } catch (e) {
      debugPrint('Conflict resolution failed: $e');
    }
  }

  Future<void> _resolveProductConflicts() async {
    // Implementation would check for products with same ID but different data
    // and resolve using configured strategy (last write wins, merge, etc.)
  }

  Future<void> _resolveSaleConflicts() async {
    // Sales conflicts are rare since they're typically immutable
    // But could handle duplicate sales with same timestamp
  }

  Future<void> _resolveCustomerConflicts() async {
    // Merge customer data from multiple sources
    // Combine contact info, purchase history, etc.
  }

  Future<void> _resolveSupplierConflicts() async {
    // Merge supplier information
    // Combine contact details, terms, performance data
  }

  Future<void> _resolvePurchaseOrderConflicts() async {
    // Handle conflicting purchase order states
    // Ensure proper workflow progression
  }

  // Team Management
  Future<TeamMember?> inviteTeamMember({
    required String email,
    required String name,
    required UserRole role,
    List<Permission>? customPermissions,
  }) async {
    if (!hasPermission(Permission.manageTeam)) {
      throw Exception('Insufficient permissions to invite team members');
    }

    try {
      final inviteId = 'invite_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create invitation document
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('invitations')
          .doc(inviteId)
          .set({
        'id': inviteId,
        'email': email,
        'name': name,
        'role': role.toString(),
        'permissions': customPermissions?.map((p) => p.toString()).toList() ?? 
                      role.defaultPermissions.map((p) => p.toString()).toList(),
        'invitedBy': _currentUserId,
        'invitedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'expiresAt': FieldValue.serverTimestamp() // Add 7 days
      });

      // Send invitation email (would integrate with email service)
      await _sendInvitationEmail(email, name, inviteId);

      await _analytics.trackEvent('team_member_invited', {
        'invited_email': email,
        'role': role.toString(),
        'invited_by': _currentUserId,
      });

      return null; // Return null until invitation is accepted
    } catch (e) {
      debugPrint('Failed to invite team member: $e');
      await _analytics.recordError(e, StackTrace.current, 'team_invite_failed');
      return null;
    }
  }

  Future<void> _sendInvitationEmail(String email, String name, String inviteId) async {
    // Integration with email service would go here
    debugPrint('Sending invitation email to $email for invite $inviteId');
  }

  Future<bool> updateTeamMemberRole(String memberId, UserRole newRole) async {
    if (!hasPermission(Permission.manageTeam)) {
      throw Exception('Insufficient permissions to update team member roles');
    }

    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('team_members')
          .doc(memberId)
          .update({
        'role': newRole.toString(),
        'permissions': newRole.defaultPermissions.map((p) => p.toString()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUserId,
      });

      await _analytics.trackEvent('team_member_role_updated', {
        'member_id': memberId,
        'new_role': newRole.toString(),
        'updated_by': _currentUserId,
      });

      return true;
    } catch (e) {
      debugPrint('Failed to update team member role: $e');
      return false;
    }
  }

  Future<bool> removeTeamMember(String memberId) async {
    if (!hasPermission(Permission.manageTeam)) {
      throw Exception('Insufficient permissions to remove team members');
    }

    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('team_members')
          .doc(memberId)
          .update({
        'isActive': false,
        'removedAt': FieldValue.serverTimestamp(),
        'removedBy': _currentUserId,
      });

      await _analytics.trackEvent('team_member_removed', {
        'member_id': memberId,
        'removed_by': _currentUserId,
      });

      return true;
    } catch (e) {
      debugPrint('Failed to remove team member: $e');
      return false;
    }
  }

  // Permission checking
  bool hasPermission(Permission permission) {
    return _currentUser?.permissions.contains(permission) ?? false;
  }

  bool canAccessFeature(String feature) {
    // Feature-level access control
    switch (feature) {
      case 'sales':
        return hasPermission(Permission.manageSales);
      case 'inventory':
        return hasPermission(Permission.manageInventory);
      case 'customers':
        return hasPermission(Permission.manageCustomers);
      case 'suppliers':
        return hasPermission(Permission.manageSuppliers);
      case 'reports':
        return hasPermission(Permission.viewReports);
      case 'settings':
        return hasPermission(Permission.manageSettings);
      default:
        return false;
    }
  }

  // Activity tracking
  Future<void> trackUserActivity({
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('user_activities')
          .add({
        'userId': _currentUserId,
        'userName': _currentUser?.name,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': {
          'platform': defaultTargetPlatform.toString(),
        },
      });
    } catch (e) {
      debugPrint('Failed to track user activity: $e');
    }
  }

  // Helper methods for local storage operations
  Future<void> _saveCustomerToLocal(Customer customer) async {
    final customersBox = await _localStorage.getBox<Map<String, dynamic>>('customers');
    await customersBox.put(customer.id, customer.toMap());
  }

  Future<void> _saveSupplierToLocal(Supplier supplier) async {
    final suppliersBox = await _localStorage.getBox<Map<String, dynamic>>('suppliers');
    await suppliersBox.put(supplier.id, supplier.toMap());
  }

  Future<void> _savePurchaseOrderToLocal(PurchaseOrder order) async {
    final ordersBox = await _localStorage.getBox<Map<String, dynamic>>('purchase_orders');
    await ordersBox.put(order.id, order.toMap());
  }

  Future<void> _saveReceiptConfigToLocal(ReceiptConfig config) async {
    final configsBox = await _localStorage.getBox<Map<String, dynamic>>('receipt_configs');
    await configsBox.put(config.id, config.toMap());
  }

  Future<List<Customer>> _getUnsyncedCustomers() async {
    final customersBox = await _localStorage.getBox<Map<String, dynamic>>('customers');
    return customersBox.values
        .map((data) => Customer.fromMap(data))
        .where((customer) => !customer.isSynced)
        .toList();
  }

  Future<List<Supplier>> _getUnsyncedSuppliers() async {
    final suppliersBox = await _localStorage.getBox<Map<String, dynamic>>('suppliers');
    return suppliersBox.values
        .map((data) => Supplier.fromMap(data))
        .where((supplier) => !supplier.isSynced)
        .toList();
  }

  Future<List<PurchaseOrder>> _getUnsyncedPurchaseOrders() async {
    final ordersBox = await _localStorage.getBox<Map<String, dynamic>>('purchase_orders');
    return ordersBox.values
        .map((data) => PurchaseOrder.fromMap(data))
        .where((order) => !order.isSynced)
        .toList();
  }

  Future<List<ReceiptConfig>> _getUnsyncedReceiptConfigs() async {
    final configsBox = await _localStorage.getBox<Map<String, dynamic>>('receipt_configs');
    return configsBox.values
        .map((data) => ReceiptConfig.fromMap(data))
        .where((config) => !config.isSynced)
        .toList();
  }

  // Cleanup and disposal
  Future<void> setOfflineMode() async {
    await _updatePresenceStatus(PresenceStatus.offline);
    _teamDataSubscription?.cancel();
    _userPresenceSubscription?.cancel();
    _presenceUpdateTimer?.cancel();
    _conflictResolutionTimer?.cancel();
  }

  Future<void> dispose() async {
    await setOfflineMode();
    _isInitialized = false;
  }
}

// Data models for team management
class TeamMember {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final UserRole role;
  final List<Permission> permissions;
  final bool isActive;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;
  final PresenceStatus presenceStatus;

  TeamMember({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.permissions,
    this.isActive = true,
    required this.joinedAt,
    this.lastSeenAt,
    this.presenceStatus = PresenceStatus.offline,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role.toString(),
      'permissions': permissions.map((p) => p.toString()).toList(),
      'isActive': isActive,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
      'lastSeenAt': lastSeenAt?.millisecondsSinceEpoch,
      'presenceStatus': presenceStatus.toString(),
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      avatarUrl: map['avatarUrl'],
      role: UserRole.values.firstWhere((r) => r.toString() == map['role']),
      permissions: (map['permissions'] as List<dynamic>?)
          ?.map((p) => Permission.values.firstWhere((perm) => perm.toString() == p))
          .toList() ?? [],
      isActive: map['isActive'] ?? true,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt']),
      lastSeenAt: map['lastSeenAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeenAt'])
          : null,
      presenceStatus: PresenceStatus.values.firstWhere(
        (s) => s.toString() == map['presenceStatus'],
        orElse: () => PresenceStatus.offline,
      ),
    );
  }

  TeamMember copyWith({
    String? name,
    String? avatarUrl,
    UserRole? role,
    List<Permission>? permissions,
    bool? isActive,
    DateTime? lastSeenAt,
    PresenceStatus? presenceStatus,
  }) {
    return TeamMember(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      joinedAt: joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      presenceStatus: presenceStatus ?? this.presenceStatus,
    );
  }
}

enum UserRole {
  manager,
  cashier,
  inventory,
  viewer,
}

enum Permission {
  manageSales,
  manageInventory,
  manageCustomers,
  manageSuppliers,
  managePurchaseOrders,
  manageTeam,
  manageSettings,
  viewReports,
  exportData,
  manageReceipts,
  processRefunds,
  applyDiscounts,
  accessCashDrawer,
}

enum PresenceStatus {
  online,
  away,
  busy,
  offline,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.manager:
        return 'Manager';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.inventory:
        return 'Inventory Staff';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case UserRole.manager:
        return 'Full access to all features';
      case UserRole.cashier:
        return 'Sales, customers, basic inventory';
      case UserRole.inventory:
        return 'Inventory, suppliers, purchase orders';
      case UserRole.viewer:
        return 'Read-only access to reports';
    }
  }

  List<Permission> get defaultPermissions {
    switch (this) {
      case UserRole.manager:
        return Permission.values; // All permissions
      case UserRole.cashier:
        return [
          Permission.manageSales,
          Permission.manageCustomers,
          Permission.manageReceipts,
          Permission.processRefunds,
          Permission.applyDiscounts,
          Permission.accessCashDrawer,
        ];
      case UserRole.inventory:
        return [
          Permission.manageInventory,
          Permission.manageSuppliers,
          Permission.managePurchaseOrders,
          Permission.viewReports,
        ];
      case UserRole.viewer:
        return [
          Permission.viewReports,
        ];
    }
  }
}

extension PermissionExtension on Permission {
  String get displayName {
    switch (this) {
      case Permission.manageSales:
        return 'Manage Sales';
      case Permission.manageInventory:
        return 'Manage Inventory';
      case Permission.manageCustomers:
        return 'Manage Customers';
      case Permission.manageSuppliers:
        return 'Manage Suppliers';
      case Permission.managePurchaseOrders:
        return 'Manage Purchase Orders';
      case Permission.manageTeam:
        return 'Manage Team';
      case Permission.manageSettings:
        return 'Manage Settings';
      case Permission.viewReports:
        return 'View Reports';
      case Permission.exportData:
        return 'Export Data';
      case Permission.manageReceipts:
        return 'Manage Receipts';
      case Permission.processRefunds:
        return 'Process Refunds';
      case Permission.applyDiscounts:
        return 'Apply Discounts';
      case Permission.accessCashDrawer:
        return 'Access Cash Drawer';
    }
  }
}

extension PresenceStatusExtension on PresenceStatus {
  String get displayName {
    switch (this) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }
}