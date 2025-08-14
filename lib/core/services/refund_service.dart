import 'dart:async';
import 'dart:convert';
import 'dart:crypto';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../models/refund.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/customer.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';
import 'team_sync_service.dart';
import 'printer_service.dart';

class RefundService {
  static RefundService? _instance;
  static RefundService get instance => _instance ??= RefundService._();
  RefundService._();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final NotificationService _notifications = NotificationService.instance;
  final TeamSyncService _teamSync = TeamSyncService.instance;
  final PrinterService _printer = PrinterService.instance;

  bool _isInitialized = false;
  late RefundConfiguration _config;

  bool get isInitialized => _isInitialized;
  RefundConfiguration get config => _config;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadConfiguration();
      _isInitialized = true;
      debugPrint('Refund service initialized');

      await _analytics.trackEvent('refund_service_initialized', {
        'approval_threshold': _config.approvalThreshold,
        'manager_pin_required': _config.requireManagerPin,
        'photo_required_for_damage': _config.requirePhotoForDamage,
      });
    } catch (e) {
      debugPrint('Refund service initialization failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'refund_service_init_failed');
    }
  }

  Future<void> _loadConfiguration() async {
    final configMap = _localStorage.getSetting<Map<String, dynamic>>('refund_configuration');
    if (configMap != null) {
      _config = RefundConfiguration.fromMap(configMap);
    } else {
      _config = RefundConfiguration.defaultConfig();
      await saveConfiguration(_config);
    }
  }

  Future<void> saveConfiguration(RefundConfiguration config) async {
    _config = config;
    await _localStorage.setSetting('refund_configuration', config.toMap());

    await _analytics.trackEvent('refund_config_updated', {
      'approval_threshold': config.approvalThreshold,
      'max_refund_days': config.maxRefundDays,
      'require_manager_pin': config.requireManagerPin,
    });
  }

  // Main refund processing methods
  Future<RefundResult> processRefund({
    required String originalSaleId,
    required List<RefundItemRequest> itemRequests,
    required RefundReason reason,
    String? reasonDetails,
    RefundMethod refundMethod = RefundMethod.original,
    String? customerNotes,
    String? internalNotes,
    List<String>? attachmentPaths,
    String? managerPin,
  }) async {
    try {
      // Validate the refund request
      final validationResult = await _validateRefundRequest(
        originalSaleId,
        itemRequests,
        reason,
        attachmentPaths,
      );

      if (!validationResult.isValid) {
        return RefundResult(
          success: false,
          message: validationResult.errorMessage!,
        );
      }

      final originalSale = validationResult.originalSale!;
      final currentUser = _teamSync.currentUser!;

      // Create refund items
      final refundItems = await _createRefundItems(itemRequests, originalSale);

      // Calculate totals
      final subtotal = refundItems.fold<double>(0, (sum, item) => sum + item.refundAmount);
      final taxAmount = subtotal * originalSale.taxRate;
      final total = subtotal + taxAmount;

      // Check if approval is required
      final requiresApproval = _requiresApproval(total, reason);

      // Verify manager PIN if required
      if (requiresApproval && _config.requireManagerPin) {
        if (managerPin == null || !_verifyManagerPin(managerPin)) {
          return RefundResult(
            success: false,
            message: 'Valid manager PIN required for refunds over \$${_config.approvalThreshold.toStringAsFixed(2)}',
          );
        }
      }

      // Create refund record
      final refund = Refund(
        originalSaleId: originalSaleId,
        originalReceiptNumber: originalSale.receiptNumber ?? originalSaleId.substring(0, 8),
        customerId: originalSale.customerId,
        customerName: originalSale.customerName ?? 'Walk-in Customer',
        items: refundItems,
        reason: reason,
        reasonDetails: reasonDetails,
        refundMethod: refundMethod,
        subtotal: subtotal,
        taxAmount: taxAmount,
        total: total,
        processedBy: currentUser.id,
        processedByName: currentUser.name,
        requiresApproval: requiresApproval,
        approvalThreshold: _config.approvalThreshold,
        managerPin: managerPin != null ? _hashPin(managerPin) : null,
        notes: internalNotes,
        customerNotes: customerNotes,
        attachments: attachmentPaths ?? [],
        isFullRefund: _isFullRefund(refundItems, originalSale),
      );

      // Add initial audit entry
      refund.addAuditEntry(
        action: 'refund_created',
        userId: currentUser.id,
        userName: currentUser.name,
        details: 'Refund created for ${refundItems.length} items',
        metadata: {
          'total_amount': total,
          'reason': reason.toString(),
          'requires_approval': requiresApproval,
        },
      );

      // Auto-approve if no approval required and user has permission
      if (!requiresApproval || _canAutoApprove(currentUser, total)) {
        await _approveRefund(refund, currentUser.id, currentUser.name, 'auto_approved');
      }

      // Save refund
      await _saveRefund(refund);

      // Process inventory updates if approved
      if (refund.isApproved) {
        await _processInventoryUpdates(refund);
      }

      // Send notifications
      await _sendRefundNotifications(refund);

      // Track analytics
      await _analytics.trackEvent('refund_processed', {
        'refund_id': refund.id,
        'original_sale_id': originalSaleId,
        'total_amount': total,
        'reason': reason.toString(),
        'requires_approval': requiresApproval,
        'items_count': refundItems.length,
        'customer_id': originalSale.customerId,
      });

      return RefundResult(
        success: true,
        message: requiresApproval 
            ? 'Refund created and pending manager approval'
            : 'Refund processed successfully',
        refund: refund,
      );
    } catch (e) {
      debugPrint('Refund processing failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'refund_processing_failed');
      
      return RefundResult(
        success: false,
        message: 'Failed to process refund: $e',
      );
    }
  }

  Future<RefundValidationResult> _validateRefundRequest(
    String originalSaleId,
    List<RefundItemRequest> itemRequests,
    RefundReason reason,
    List<String>? attachmentPaths,
  ) async {
    // Get original sale
    final originalSale = await _getOriginalSale(originalSaleId);
    if (originalSale == null) {
      return RefundValidationResult(
        isValid: false,
        errorMessage: 'Original sale not found',
      );
    }

    // Check refund time limit
    final daysSinceSale = DateTime.now().difference(originalSale.createdAt).inDays;
    if (daysSinceSale > _config.maxRefundDays) {
      return RefundValidationResult(
        isValid: false,
        errorMessage: 'Refund period expired. Maximum ${_config.maxRefundDays} days allowed.',
      );
    }

    // Check if items exist in original sale
    for (final request in itemRequests) {
      final originalItem = originalSale.items.firstWhere(
        (item) => item.productId == request.productId,
        orElse: () => throw Exception('Item ${request.productId} not found in original sale'),
      );

      if (request.quantity > originalItem.quantity) {
        return RefundValidationResult(
          isValid: false,
          errorMessage: 'Cannot refund more items than originally purchased for ${originalItem.productName}',
        );
      }
    }

    // Check for photo requirement
    if (reason.requiresPhoto && (attachmentPaths == null || attachmentPaths.isEmpty)) {
      return RefundValidationResult(
        isValid: false,
        errorMessage: 'Photo required for ${reason.displayName} refunds',
      );
    }

    // Check for duplicate refunds
    final existingRefunds = await getRefundsBySale(originalSaleId);
    for (final request in itemRequests) {
      final totalRefunded = existingRefunds
          .where((refund) => refund.isCompleted && !refund.isDeleted)
          .expand((refund) => refund.items)
          .where((item) => item.productId == request.productId)
          .fold<int>(0, (sum, item) => sum + item.refundQuantity);

      final originalQuantity = originalSale.items
          .firstWhere((item) => item.productId == request.productId)
          .quantity;

      if (totalRefunded + request.quantity > originalQuantity) {
        return RefundValidationResult(
          isValid: false,
          errorMessage: 'Cannot refund more items than available. Already refunded: $totalRefunded',
        );
      }
    }

    return RefundValidationResult(
      isValid: true,
      originalSale: originalSale,
    );
  }

  Future<List<RefundItem>> _createRefundItems(
    List<RefundItemRequest> requests,
    Sale originalSale,
  ) async {
    final refundItems = <RefundItem>[];

    for (final request in requests) {
      final originalItem = originalSale.items.firstWhere(
        (item) => item.productId == request.productId,
      );

      final refundAmount = originalItem.unitPrice * request.quantity;

      refundItems.add(RefundItem(
        productId: request.productId,
        productName: originalItem.productName,
        productSku: originalItem.productSku,
        originalQuantity: originalItem.quantity,
        refundQuantity: request.quantity,
        unitPrice: originalItem.unitPrice,
        refundAmount: refundAmount,
        restockAction: request.restockAction,
        itemCondition: request.itemCondition,
        notes: request.notes,
        photos: request.photos,
      ));
    }

    return refundItems;
  }

  bool _requiresApproval(double total, RefundReason reason) {
    // Check amount threshold
    if (total >= _config.approvalThreshold) {
      return true;
    }

    // Check if specific reasons require approval
    if (_config.reasonsRequiringApproval.contains(reason)) {
      return true;
    }

    return false;
  }

  bool _canAutoApprove(dynamic user, double amount) {
    // Managers can auto-approve up to their limit
    if (user.role.toString() == 'UserRole.manager') {
      return amount <= _config.managerAutoApprovalLimit;
    }

    return false;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + _config.pinSalt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyManagerPin(String pin) {
    final hashedPin = _hashPin(pin);
    return hashedPin == _config.managerPinHash;
  }

  bool _isFullRefund(List<RefundItem> refundItems, Sale originalSale) {
    return refundItems.length == originalSale.items.length &&
           refundItems.every((refundItem) {
             final originalItem = originalSale.items.firstWhere(
               (item) => item.productId == refundItem.productId,
             );
             return refundItem.refundQuantity >= originalItem.quantity;
           });
  }

  // Approval workflow methods
  Future<bool> approveRefund(String refundId, String managerPin) async {
    try {
      final refund = await getRefund(refundId);
      if (refund == null) {
        return false;
      }

      // Verify manager PIN
      if (!_verifyManagerPin(managerPin)) {
        await _analytics.trackEvent('refund_approval_failed', {
          'refund_id': refundId,
          'reason': 'invalid_pin',
        });
        return false;
      }

      final currentUser = _teamSync.currentUser!;
      await _approveRefund(refund, currentUser.id, currentUser.name, 'manager_approved');

      // Process inventory updates
      await _processInventoryUpdates(refund);

      // Send notifications
      await _sendRefundNotifications(refund);

      return true;
    } catch (e) {
      debugPrint('Refund approval failed: $e');
      return false;
    }
  }

  Future<void> _approveRefund(Refund refund, String userId, String userName, String approvalType) async {
    final approvedRefund = refund.copyWith(
      status: RefundStatus.approved,
      approvedBy: userId,
      approvedByName: userName,
      approvedAt: DateTime.now(),
    );

    approvedRefund.addAuditEntry(
      action: 'refund_approved',
      userId: userId,
      userName: userName,
      details: 'Refund approved via $approvalType',
      metadata: {
        'approval_type': approvalType,
        'total_amount': refund.total,
      },
    );

    await _saveRefund(approvedRefund);

    await _analytics.trackEvent('refund_approved', {
      'refund_id': refund.id,
      'approved_by': userId,
      'approval_type': approvalType,
      'total_amount': refund.total,
    });
  }

  Future<bool> rejectRefund(String refundId, String reason, String managerPin) async {
    try {
      final refund = await getRefund(refundId);
      if (refund == null) {
        return false;
      }

      // Verify manager PIN
      if (!_verifyManagerPin(managerPin)) {
        return false;
      }

      final currentUser = _teamSync.currentUser!;
      final rejectedRefund = refund.copyWith(
        status: RefundStatus.rejected,
        rejectedBy: currentUser.id,
        rejectionReason: reason,
        rejectedAt: DateTime.now(),
      );

      rejectedRefund.addAuditEntry(
        action: 'refund_rejected',
        userId: currentUser.id,
        userName: currentUser.name,
        details: 'Refund rejected: $reason',
        metadata: {
          'rejection_reason': reason,
          'total_amount': refund.total,
        },
      );

      await _saveRefund(rejectedRefund);

      // Send rejection notification
      await _sendRefundNotifications(rejectedRefund);

      await _analytics.trackEvent('refund_rejected', {
        'refund_id': refund.id,
        'rejected_by': currentUser.id,
        'rejection_reason': reason,
        'total_amount': refund.total,
      });

      return true;
    } catch (e) {
      debugPrint('Refund rejection failed: $e');
      return false;
    }
  }

  Future<bool> completeRefund(String refundId) async {
    try {
      final refund = await getRefund(refundId);
      if (refund == null || !refund.isApproved) {
        return false;
      }

      final currentUser = _teamSync.currentUser!;
      final completedRefund = refund.copyWith(
        status: RefundStatus.completed,
      );

      completedRefund.addAuditEntry(
        action: 'refund_completed',
        userId: currentUser.id,
        userName: currentUser.name,
        details: 'Refund payment completed',
        metadata: {
          'refund_method': refund.refundMethod.toString(),
          'total_amount': refund.total,
        },
      );

      await _saveRefund(completedRefund);

      await _analytics.trackEvent('refund_completed', {
        'refund_id': refund.id,
        'completed_by': currentUser.id,
        'refund_method': refund.refundMethod.toString(),
        'total_amount': refund.total,
      });

      return true;
    } catch (e) {
      debugPrint('Refund completion failed: $e');
      return false;
    }
  }

  // Inventory management
  Future<void> _processInventoryUpdates(Refund refund) async {
    for (final item in refund.items) {
      if (item.restockAction.affectsInventory) {
        try {
          final product = _localStorage.getProduct(item.productId);
          if (product != null) {
            final updatedProduct = product.copyWith(
              stockQuantity: product.stockQuantity + item.refundQuantity,
            );
            await _localStorage.saveProduct(updatedProduct);

            refund.addAuditEntry(
              action: 'inventory_updated',
              userId: _teamSync.currentUser!.id,
              userName: _teamSync.currentUser!.name,
              details: 'Restocked ${item.refundQuantity} units of ${item.productName}',
              metadata: {
                'product_id': item.productId,
                'quantity_restocked': item.refundQuantity,
                'new_stock_level': updatedProduct.stockQuantity,
              },
            );
          }
        } catch (e) {
          debugPrint('Failed to update inventory for ${item.productId}: $e');
        }
      }
    }
  }

  // Data access methods
  Future<Sale?> _getOriginalSale(String saleId) async {
    try {
      return _localStorage.getSale(saleId);
    } catch (e) {
      debugPrint('Failed to get original sale: $e');
      return null;
    }
  }

  Future<void> _saveRefund(Refund refund) async {
    final refundsBox = await _localStorage.getBox<Map<String, dynamic>>('refunds');
    await refundsBox.put(refund.id, refund.toMap());
  }

  Future<Refund?> getRefund(String refundId) async {
    try {
      final refundsBox = await _localStorage.getBox<Map<String, dynamic>>('refunds');
      final refundMap = refundsBox.get(refundId);
      
      if (refundMap != null) {
        return Refund.fromMap(refundMap);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get refund: $e');
      return null;
    }
  }

  Future<List<Refund>> getAllRefunds({
    bool includeDeleted = false,
    RefundStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final refundsBox = await _localStorage.getBox<Map<String, dynamic>>('refunds');
      final refunds = refundsBox.values
          .map((data) => Refund.fromMap(data))
          .where((refund) => includeDeleted || !refund.isDeleted)
          .toList();

      var filteredRefunds = refunds;

      if (status != null) {
        filteredRefunds = filteredRefunds.where((refund) => refund.status == status).toList();
      }

      if (startDate != null) {
        filteredRefunds = filteredRefunds.where((refund) => refund.createdAt.isAfter(startDate)).toList();
      }

      if (endDate != null) {
        filteredRefunds = filteredRefunds.where((refund) => refund.createdAt.isBefore(endDate)).toList();
      }

      // Sort by creation date (newest first)
      filteredRefunds.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return filteredRefunds;
    } catch (e) {
      debugPrint('Failed to get refunds: $e');
      return [];
    }
  }

  Future<List<Refund>> getRefundsBySale(String saleId) async {
    final allRefunds = await getAllRefunds();
    return allRefunds.where((refund) => refund.originalSaleId == saleId).toList();
  }

  Future<List<Refund>> getPendingApprovals() async {
    return await getAllRefunds(status: RefundStatus.pending);
  }

  // Reporting methods
  Future<RefundSummary> getRefundSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final refunds = await getAllRefunds(startDate: start, endDate: end);

    final completedRefunds = refunds.where((r) => r.isCompleted).toList();
    final totalRefundAmount = completedRefunds.fold<double>(0, (sum, refund) => sum + refund.total);
    
    final reasonCounts = <RefundReason, int>{};
    for (final refund in refunds) {
      reasonCounts[refund.reason] = (reasonCounts[refund.reason] ?? 0) + 1;
    }

    return RefundSummary(
      totalRefunds: refunds.length,
      completedRefunds: completedRefunds.length,
      pendingRefunds: refunds.where((r) => r.isPending).length,
      rejectedRefunds: refunds.where((r) => r.isRejected).length,
      totalRefundAmount: totalRefundAmount,
      averageRefundAmount: completedRefunds.isNotEmpty ? totalRefundAmount / completedRefunds.length : 0,
      reasonBreakdown: reasonCounts,
      periodStart: start,
      periodEnd: end,
    );
  }

  // Notification methods
  Future<void> _sendRefundNotifications(Refund refund) async {
    try {
      // Notify customer if email available
      if (refund.customerId != null) {
        // Implementation would send email notification
        debugPrint('Sending refund notification to customer ${refund.customerName}');
      }

      // Notify managers for pending approvals
      if (refund.needsApproval) {
        await _notifications.showNotification(
          id: refund.id.hashCode,
          title: '💰 Refund Approval Required',
          body: 'Refund of \$${refund.total.toStringAsFixed(2)} needs manager approval',
          payload: refund.id,
        );
      }

      // Notify staff of completed refunds
      if (refund.isCompleted) {
        await _notifications.showNotification(
          id: refund.id.hashCode,
          title: '✅ Refund Completed',
          body: 'Refund ${refund.refundNumber} completed successfully',
          payload: refund.id,
        );
      }
    } catch (e) {
      debugPrint('Failed to send refund notifications: $e');
    }
  }

  // Receipt generation
  Future<bool> printRefundReceipt(String refundId) async {
    try {
      final refund = await getRefund(refundId);
      if (refund == null) {
        return false;
      }

      // Generate refund receipt text
      final receiptText = _generateRefundReceiptText(refund);
      
      // Use printer service to print
      // Implementation would integrate with printer service
      debugPrint('Printing refund receipt for ${refund.refundNumber}');
      
      return true;
    } catch (e) {
      debugPrint('Failed to print refund receipt: $e');
      return false;
    }
  }

  String _generateRefundReceiptText(Refund refund) {
    final buffer = StringBuffer();
    
    buffer.writeln('========== REFUND RECEIPT ==========');
    buffer.writeln('Refund #: ${refund.refundNumber}');
    buffer.writeln('Original Sale: ${refund.originalReceiptNumber}');
    buffer.writeln('Date: ${refund.processedAt}');
    buffer.writeln('Customer: ${refund.customerName}');
    buffer.writeln('Reason: ${refund.reason.displayName}');
    if (refund.reasonDetails != null) {
      buffer.writeln('Details: ${refund.reasonDetails}');
    }
    buffer.writeln('===================================');
    
    for (final item in refund.items) {
      buffer.writeln('${item.productName}');
      buffer.writeln('  Qty: ${item.refundQuantity} x \$${item.unitPrice.toStringAsFixed(2)}');
      buffer.writeln('  Amount: \$${item.refundAmount.toStringAsFixed(2)}');
      if (item.notes != null) {
        buffer.writeln('  Notes: ${item.notes}');
      }
      buffer.writeln('');
    }
    
    buffer.writeln('===================================');
    buffer.writeln('Subtotal: \$${refund.subtotal.toStringAsFixed(2)}');
    buffer.writeln('Tax: \$${refund.taxAmount.toStringAsFixed(2)}');
    buffer.writeln('TOTAL REFUND: \$${refund.total.toStringAsFixed(2)}');
    buffer.writeln('===================================');
    buffer.writeln('Refund Method: ${refund.refundMethod.displayName}');
    buffer.writeln('Processed by: ${refund.processedByName}');
    if (refund.approvedByName != null) {
      buffer.writeln('Approved by: ${refund.approvedByName}');
    }
    buffer.writeln('Status: ${refund.statusDisplayText}');
    
    if (refund.customerNotes != null) {
      buffer.writeln('');
      buffer.writeln('Notes: ${refund.customerNotes}');
    }
    
    buffer.writeln('');
    buffer.writeln('Thank you for your business!');
    
    return buffer.toString();
  }
}

// Supporting classes
class RefundConfiguration {
  final double approvalThreshold;
  final int maxRefundDays;
  final bool requireManagerPin;
  final bool requirePhotoForDamage;
  final double managerAutoApprovalLimit;
  final List<RefundReason> reasonsRequiringApproval;
  final String managerPinHash;
  final String pinSalt;
  final bool allowPartialRefunds;
  final bool autoRestockOnApproval;

  RefundConfiguration({
    this.approvalThreshold = 100.0,
    this.maxRefundDays = 30,
    this.requireManagerPin = true,
    this.requirePhotoForDamage = true,
    this.managerAutoApprovalLimit = 500.0,
    this.reasonsRequiringApproval = const [],
    this.managerPinHash = '',
    this.pinSalt = 'pos_refund_salt_2024',
    this.allowPartialRefunds = true,
    this.autoRestockOnApproval = true,
  });

  factory RefundConfiguration.defaultConfig() {
    return RefundConfiguration(
      reasonsRequiringApproval: [
        RefundReason.changeOfMind,
        RefundReason.other,
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'approvalThreshold': approvalThreshold,
      'maxRefundDays': maxRefundDays,
      'requireManagerPin': requireManagerPin,
      'requirePhotoForDamage': requirePhotoForDamage,
      'managerAutoApprovalLimit': managerAutoApprovalLimit,
      'reasonsRequiringApproval': reasonsRequiringApproval.map((r) => r.toString()).toList(),
      'managerPinHash': managerPinHash,
      'pinSalt': pinSalt,
      'allowPartialRefunds': allowPartialRefunds,
      'autoRestockOnApproval': autoRestockOnApproval,
    };
  }

  factory RefundConfiguration.fromMap(Map<String, dynamic> map) {
    return RefundConfiguration(
      approvalThreshold: map['approvalThreshold']?.toDouble() ?? 100.0,
      maxRefundDays: map['maxRefundDays'] ?? 30,
      requireManagerPin: map['requireManagerPin'] ?? true,
      requirePhotoForDamage: map['requirePhotoForDamage'] ?? true,
      managerAutoApprovalLimit: map['managerAutoApprovalLimit']?.toDouble() ?? 500.0,
      reasonsRequiringApproval: (map['reasonsRequiringApproval'] as List?)
          ?.map((r) => RefundReason.values.firstWhere((reason) => reason.toString() == r))
          .toList() ?? [],
      managerPinHash: map['managerPinHash'] ?? '',
      pinSalt: map['pinSalt'] ?? 'pos_refund_salt_2024',
      allowPartialRefunds: map['allowPartialRefunds'] ?? true,
      autoRestockOnApproval: map['autoRestockOnApproval'] ?? true,
    );
  }
}

class RefundItemRequest {
  final String productId;
  final int quantity;
  final RestockAction restockAction;
  final String? itemCondition;
  final String? notes;
  final List<String> photos;

  RefundItemRequest({
    required this.productId,
    required this.quantity,
    this.restockAction = RestockAction.restock,
    this.itemCondition,
    this.notes,
    this.photos = const [],
  });
}

class RefundResult {
  final bool success;
  final String message;
  final Refund? refund;

  RefundResult({
    required this.success,
    required this.message,
    this.refund,
  });
}

class RefundValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Sale? originalSale;

  RefundValidationResult({
    required this.isValid,
    this.errorMessage,
    this.originalSale,
  });
}

class RefundSummary {
  final int totalRefunds;
  final int completedRefunds;
  final int pendingRefunds;
  final int rejectedRefunds;
  final double totalRefundAmount;
  final double averageRefundAmount;
  final Map<RefundReason, int> reasonBreakdown;
  final DateTime periodStart;
  final DateTime periodEnd;

  RefundSummary({
    required this.totalRefunds,
    required this.completedRefunds,
    required this.pendingRefunds,
    required this.rejectedRefunds,
    required this.totalRefundAmount,
    required this.averageRefundAmount,
    required this.reasonBreakdown,
    required this.periodStart,
    required this.periodEnd,
  });

  double get refundRate {
    return totalRefunds > 0 ? (completedRefunds / totalRefunds) * 100 : 0;
  }

  RefundReason? get mostCommonReason {
    if (reasonBreakdown.isEmpty) return null;
    return reasonBreakdown.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}