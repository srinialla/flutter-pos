import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'refund.g.dart';

@HiveType(typeId: 17)
class Refund extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String refundNumber; // Auto-generated refund number

  @HiveField(2)
  String originalSaleId;

  @HiveField(3)
  String originalReceiptNumber;

  @HiveField(4)
  String? customerId;

  @HiveField(5)
  String customerName; // Cached for quick access

  @HiveField(6)
  List<RefundItem> items;

  @HiveField(7)
  RefundReason reason;

  @HiveField(8)
  String? reasonDetails; // Additional explanation

  @HiveField(9)
  RefundStatus status;

  @HiveField(10)
  RefundMethod refundMethod;

  @HiveField(11)
  double subtotal;

  @HiveField(12)
  double taxAmount;

  @HiveField(13)
  double total;

  @HiveField(14)
  String processedBy; // User ID who initiated the refund

  @HiveField(15)
  String processedByName; // Cached name

  @HiveField(16)
  DateTime processedAt;

  @HiveField(17)
  String? approvedBy; // Manager who approved (if required)

  @HiveField(18)
  String? approvedByName;

  @HiveField(19)
  DateTime? approvedAt;

  @HiveField(20)
  String? rejectedBy;

  @HiveField(21)
  String? rejectionReason;

  @HiveField(22)
  DateTime? rejectedAt;

  @HiveField(23)
  bool requiresApproval;

  @HiveField(24)
  double approvalThreshold; // Amount that triggered approval requirement

  @HiveField(25)
  String? managerPin; // Encrypted manager PIN (if used)

  @HiveField(26)
  List<RefundAuditEntry> auditTrail;

  @HiveField(27)
  String? notes; // Internal staff notes

  @HiveField(28)
  String? customerNotes; // Customer-facing notes

  @HiveField(29)
  List<String> attachments; // Photos of damaged items, etc.

  @HiveField(30)
  bool isFullRefund; // Whether all items from original sale were refunded

  @HiveField(31)
  DateTime createdAt;

  @HiveField(32)
  DateTime updatedAt;

  @HiveField(33)
  bool isSynced;

  @HiveField(34)
  String? deviceId;

  @HiveField(35)
  bool isDeleted;

  Refund({
    String? id,
    String? refundNumber,
    required this.originalSaleId,
    required this.originalReceiptNumber,
    this.customerId,
    required this.customerName,
    List<RefundItem>? items,
    required this.reason,
    this.reasonDetails,
    this.status = RefundStatus.pending,
    this.refundMethod = RefundMethod.original,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
    required this.processedBy,
    required this.processedByName,
    DateTime? processedAt,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectedBy,
    this.rejectionReason,
    this.rejectedAt,
    this.requiresApproval = false,
    this.approvalThreshold = 0.0,
    this.managerPin,
    List<RefundAuditEntry>? auditTrail,
    this.notes,
    this.customerNotes,
    List<String>? attachments,
    this.isFullRefund = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.deviceId,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        refundNumber = refundNumber ?? _generateRefundNumber(),
        items = items ?? [],
        auditTrail = auditTrail ?? [],
        attachments = attachments ?? [],
        processedAt = processedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String _generateRefundNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(8);
    return 'REF${now.year}${now.month.toString().padLeft(2, '0')}$timestamp';
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'refundNumber': refundNumber,
      'originalSaleId': originalSaleId,
      'originalReceiptNumber': originalReceiptNumber,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason.toString(),
      'reasonDetails': reasonDetails,
      'status': status.toString(),
      'refundMethod': refundMethod.toString(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'total': total,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'processedAt': processedAt.millisecondsSinceEpoch,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'rejectedBy': rejectedBy,
      'rejectionReason': rejectionReason,
      'rejectedAt': rejectedAt?.millisecondsSinceEpoch,
      'requiresApproval': requiresApproval,
      'approvalThreshold': approvalThreshold,
      'managerPin': managerPin,
      'auditTrail': auditTrail.map((entry) => entry.toMap()).toList(),
      'notes': notes,
      'customerNotes': customerNotes,
      'attachments': attachments,
      'isFullRefund': isFullRefund,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'isDeleted': isDeleted,
    };
  }

  // Create from Map (Firebase)
  factory Refund.fromMap(Map<String, dynamic> map) {
    return Refund(
      id: map['id'],
      refundNumber: map['refundNumber'],
      originalSaleId: map['originalSaleId'],
      originalReceiptNumber: map['originalReceiptNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      items: (map['items'] as List).map((item) => RefundItem.fromMap(item)).toList(),
      reason: RefundReason.values.firstWhere(
        (e) => e.toString() == map['reason'],
        orElse: () => RefundReason.customerRequest,
      ),
      reasonDetails: map['reasonDetails'],
      status: RefundStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => RefundStatus.pending,
      ),
      refundMethod: RefundMethod.values.firstWhere(
        (e) => e.toString() == map['refundMethod'],
        orElse: () => RefundMethod.original,
      ),
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      taxAmount: map['taxAmount']?.toDouble() ?? 0.0,
      total: map['total']?.toDouble() ?? 0.0,
      processedBy: map['processedBy'],
      processedByName: map['processedByName'],
      processedAt: DateTime.fromMillisecondsSinceEpoch(map['processedAt']),
      approvedBy: map['approvedBy'],
      approvedByName: map['approvedByName'],
      approvedAt: map['approvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'])
          : null,
      rejectedBy: map['rejectedBy'],
      rejectionReason: map['rejectionReason'],
      rejectedAt: map['rejectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['rejectedAt'])
          : null,
      requiresApproval: map['requiresApproval'] ?? false,
      approvalThreshold: map['approvalThreshold']?.toDouble() ?? 0.0,
      managerPin: map['managerPin'],
      auditTrail: (map['auditTrail'] as List?)
          ?.map((entry) => RefundAuditEntry.fromMap(entry))
          .toList() ?? [],
      notes: map['notes'],
      customerNotes: map['customerNotes'],
      attachments: List<String>.from(map['attachments'] ?? []),
      isFullRefund: map['isFullRefund'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      deviceId: map['deviceId'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // Calculate totals
  void calculateTotals(double originalTaxRate) {
    subtotal = items.fold(0.0, (sum, item) => sum + item.refundAmount);
    taxAmount = subtotal * originalTaxRate;
    total = subtotal + taxAmount;
    updatedAt = DateTime.now();
  }

  // Add audit entry
  void addAuditEntry({
    required String action,
    required String userId,
    required String userName,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    auditTrail.add(RefundAuditEntry(
      action: action,
      userId: userId,
      userName: userName,
      timestamp: DateTime.now(),
      details: details,
      metadata: metadata ?? {},
    ));
    updatedAt = DateTime.now();
  }

  // Copy with method for updates
  Refund copyWith({
    List<RefundItem>? items,
    RefundReason? reason,
    String? reasonDetails,
    RefundStatus? status,
    RefundMethod? refundMethod,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? rejectedAt,
    String? notes,
    String? customerNotes,
    List<String>? attachments,
    bool? isFullRefund,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Refund(
      id: id,
      refundNumber: refundNumber,
      originalSaleId: originalSaleId,
      originalReceiptNumber: originalReceiptNumber,
      customerId: customerId,
      customerName: customerName,
      items: items ?? this.items,
      reason: reason ?? this.reason,
      reasonDetails: reasonDetails ?? this.reasonDetails,
      status: status ?? this.status,
      refundMethod: refundMethod ?? this.refundMethod,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      processedBy: processedBy,
      processedByName: processedByName,
      processedAt: processedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      requiresApproval: requiresApproval,
      approvalThreshold: approvalThreshold,
      managerPin: managerPin,
      auditTrail: auditTrail,
      notes: notes ?? this.notes,
      customerNotes: customerNotes ?? this.customerNotes,
      attachments: attachments ?? this.attachments,
      isFullRefund: isFullRefund ?? this.isFullRefund,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? false,
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // Helper methods
  bool get isApproved => status == RefundStatus.approved;
  bool get isRejected => status == RefundStatus.rejected;
  bool get isCompleted => status == RefundStatus.completed;
  bool get isPending => status == RefundStatus.pending;
  bool get needsApproval => requiresApproval && status == RefundStatus.pending;

  int get daysSinceCreated => DateTime.now().difference(createdAt).inDays;

  String get statusDisplayText {
    if (requiresApproval && status == RefundStatus.pending) {
      return 'Pending Manager Approval';
    }
    return status.displayName;
  }

  @override
  String toString() {
    return 'Refund(id: $id, refundNumber: $refundNumber, total: \$${total.toStringAsFixed(2)}, status: $status)';
  }
}

@HiveType(typeId: 18)
class RefundItem extends HiveObject {
  @HiveField(0)
  String productId;

  @HiveField(1)
  String productName;

  @HiveField(2)
  String? productSku;

  @HiveField(3)
  int originalQuantity; // Quantity from original sale

  @HiveField(4)
  int refundQuantity; // Quantity being refunded

  @HiveField(5)
  double unitPrice;

  @HiveField(6)
  double refundAmount; // Total refund amount for this item

  @HiveField(7)
  RestockAction restockAction;

  @HiveField(8)
  String? itemCondition; // Description of item condition

  @HiveField(9)
  String? notes;

  @HiveField(10)
  List<String> photos; // Photos of damaged items

  RefundItem({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.originalQuantity,
    required this.refundQuantity,
    required this.unitPrice,
    required this.refundAmount,
    this.restockAction = RestockAction.restock,
    this.itemCondition,
    this.notes,
    List<String>? photos,
  }) : photos = photos ?? [];

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'originalQuantity': originalQuantity,
      'refundQuantity': refundQuantity,
      'unitPrice': unitPrice,
      'refundAmount': refundAmount,
      'restockAction': restockAction.toString(),
      'itemCondition': itemCondition,
      'notes': notes,
      'photos': photos,
    };
  }

  factory RefundItem.fromMap(Map<String, dynamic> map) {
    return RefundItem(
      productId: map['productId'],
      productName: map['productName'],
      productSku: map['productSku'],
      originalQuantity: map['originalQuantity'],
      refundQuantity: map['refundQuantity'],
      unitPrice: map['unitPrice']?.toDouble(),
      refundAmount: map['refundAmount']?.toDouble(),
      restockAction: RestockAction.values.firstWhere(
        (e) => e.toString() == map['restockAction'],
        orElse: () => RestockAction.restock,
      ),
      itemCondition: map['itemCondition'],
      notes: map['notes'],
      photos: List<String>.from(map['photos'] ?? []),
    );
  }

  bool get isPartialRefund => refundQuantity < originalQuantity;
  bool get isFullRefund => refundQuantity >= originalQuantity;
}

@HiveType(typeId: 19)
class RefundAuditEntry extends HiveObject {
  @HiveField(0)
  String action; // What happened

  @HiveField(1)
  String userId; // Who did it

  @HiveField(2)
  String userName; // Cached user name

  @HiveField(3)
  DateTime timestamp; // When it happened

  @HiveField(4)
  String? details; // Additional details

  @HiveField(5)
  Map<String, dynamic> metadata; // Any additional data

  RefundAuditEntry({
    required this.action,
    required this.userId,
    required this.userName,
    required this.timestamp,
    this.details,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'details': details,
      'metadata': metadata,
    };
  }

  factory RefundAuditEntry.fromMap(Map<String, dynamic> map) {
    return RefundAuditEntry(
      action: map['action'],
      userId: map['userId'],
      userName: map['userName'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      details: map['details'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

// Enums
@HiveType(typeId: 20)
enum RefundReason {
  @HiveField(0)
  damaged,
  @HiveField(1)
  wrongItem,
  @HiveField(2)
  customerRequest,
  @HiveField(3)
  defective,
  @HiveField(4)
  expired,
  @HiveField(5)
  notAsDescribed,
  @HiveField(6)
  changeOfMind,
  @HiveField(7)
  duplicate,
  @HiveField(8)
  other,
}

@HiveType(typeId: 21)
enum RefundStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  approved,
  @HiveField(2)
  rejected,
  @HiveField(3)
  completed,
  @HiveField(4)
  cancelled,
}

@HiveType(typeId: 22)
enum RefundMethod {
  @HiveField(0)
  original, // Refund to original payment method
  @HiveField(1)
  cash,
  @HiveField(2)
  storeCredit,
  @HiveField(3)
  bankTransfer,
  @HiveField(4)
  giftCard,
}

@HiveType(typeId: 23)
enum RestockAction {
  @HiveField(0)
  restock, // Return to inventory
  @HiveField(1)
  damaged, // Mark as damaged/waste
  @HiveField(2)
  donate, // Donate item
  @HiveField(3)
  destroy, // Destroy item
  @HiveField(4)
  return, // Return to supplier
}

// Extensions for display names
extension RefundReasonExtension on RefundReason {
  String get displayName {
    switch (this) {
      case RefundReason.damaged:
        return 'Damaged Item';
      case RefundReason.wrongItem:
        return 'Wrong Item';
      case RefundReason.customerRequest:
        return 'Customer Request';
      case RefundReason.defective:
        return 'Defective';
      case RefundReason.expired:
        return 'Expired';
      case RefundReason.notAsDescribed:
        return 'Not as Described';
      case RefundReason.changeOfMind:
        return 'Change of Mind';
      case RefundReason.duplicate:
        return 'Duplicate Purchase';
      case RefundReason.other:
        return 'Other';
    }
  }

  String get description {
    switch (this) {
      case RefundReason.damaged:
        return 'Item was damaged during shipping or handling';
      case RefundReason.wrongItem:
        return 'Customer received wrong item';
      case RefundReason.customerRequest:
        return 'Customer requested refund';
      case RefundReason.defective:
        return 'Item has manufacturing defects';
      case RefundReason.expired:
        return 'Item is past expiration date';
      case RefundReason.notAsDescribed:
        return 'Item does not match description';
      case RefundReason.changeOfMind:
        return 'Customer changed their mind';
      case RefundReason.duplicate:
        return 'Duplicate purchase/payment';
      case RefundReason.other:
        return 'Other reason (see notes)';
    }
  }

  bool get requiresPhoto {
    return this == RefundReason.damaged || 
           this == RefundReason.defective ||
           this == RefundReason.expired;
  }
}

extension RefundStatusExtension on RefundStatus {
  String get displayName {
    switch (this) {
      case RefundStatus.pending:
        return 'Pending';
      case RefundStatus.approved:
        return 'Approved';
      case RefundStatus.rejected:
        return 'Rejected';
      case RefundStatus.completed:
        return 'Completed';
      case RefundStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get description {
    switch (this) {
      case RefundStatus.pending:
        return 'Waiting for processing or approval';
      case RefundStatus.approved:
        return 'Approved for processing';
      case RefundStatus.rejected:
        return 'Refund request rejected';
      case RefundStatus.completed:
        return 'Refund completed successfully';
      case RefundStatus.cancelled:
        return 'Refund cancelled';
    }
  }
}

extension RefundMethodExtension on RefundMethod {
  String get displayName {
    switch (this) {
      case RefundMethod.original:
        return 'Original Payment Method';
      case RefundMethod.cash:
        return 'Cash';
      case RefundMethod.storeCredit:
        return 'Store Credit';
      case RefundMethod.bankTransfer:
        return 'Bank Transfer';
      case RefundMethod.giftCard:
        return 'Gift Card';
    }
  }
}

extension RestockActionExtension on RestockAction {
  String get displayName {
    switch (this) {
      case RestockAction.restock:
        return 'Return to Inventory';
      case RestockAction.damaged:
        return 'Mark as Damaged/Waste';
      case RestockAction.donate:
        return 'Donate';
      case RestockAction.destroy:
        return 'Destroy';
      case RestockAction.return:
        return 'Return to Supplier';
    }
  }

  String get description {
    switch (this) {
      case RestockAction.restock:
        return 'Add back to sellable inventory';
      case RestockAction.damaged:
        return 'Mark as damaged and remove from inventory';
      case RestockAction.donate:
        return 'Donate item to charity';
      case RestockAction.destroy:
        return 'Destroy item (expired/unsafe)';
      case RestockAction.return:
        return 'Return to supplier';
    }
  }

  bool get affectsInventory {
    return this == RestockAction.restock;
  }
}