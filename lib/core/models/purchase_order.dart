import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'purchase_order.g.dart';

@HiveType(typeId: 9)
class PurchaseOrder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String orderNumber; // Auto-generated PO number

  @HiveField(2)
  String supplierId;

  @HiveField(3)
  String supplierName; // Cached for quick access

  @HiveField(4)
  List<PurchaseOrderItem> items;

  @HiveField(5)
  PurchaseOrderStatus status;

  @HiveField(6)
  DateTime orderDate;

  @HiveField(7)
  DateTime expectedDeliveryDate;

  @HiveField(8)
  DateTime? actualDeliveryDate;

  @HiveField(9)
  double subtotal;

  @HiveField(10)
  double taxRate;

  @HiveField(11)
  double taxAmount;

  @HiveField(12)
  double shippingCost;

  @HiveField(13)
  double discount;

  @HiveField(14)
  double total;

  @HiveField(15)
  String? notes;

  @HiveField(16)
  String? internalNotes; // Private notes for staff

  @HiveField(17)
  String createdBy; // User ID who created the order

  @HiveField(18)
  String? approvedBy; // User ID who approved the order

  @HiveField(19)
  DateTime? approvedAt;

  @HiveField(20)
  String? receivedBy; // User ID who received the order

  @HiveField(21)
  DateTime? receivedAt;

  @HiveField(22)
  List<String> attachments; // File paths or URLs

  @HiveField(23)
  DateTime createdAt;

  @HiveField(24)
  DateTime updatedAt;

  @HiveField(25)
  bool isSynced;

  @HiveField(26)
  String? deviceId;

  @HiveField(27)
  bool isDeleted;

  PurchaseOrder({
    String? id,
    String? orderNumber,
    required this.supplierId,
    required this.supplierName,
    List<PurchaseOrderItem>? items,
    this.status = PurchaseOrderStatus.draft,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    this.actualDeliveryDate,
    this.subtotal = 0.0,
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.shippingCost = 0.0,
    this.discount = 0.0,
    this.total = 0.0,
    this.notes,
    this.internalNotes,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.receivedBy,
    this.receivedAt,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.deviceId,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        orderNumber = orderNumber ?? _generateOrderNumber(),
        items = items ?? [],
        attachments = attachments ?? [],
        orderDate = orderDate ?? DateTime.now(),
        expectedDeliveryDate = expectedDeliveryDate ?? DateTime.now().add(const Duration(days: 7)),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String _generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(8);
    return 'PO${now.year}${now.month.toString().padLeft(2, '0')}$timestamp';
  }

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status.toString(),
      'orderDate': orderDate.millisecondsSinceEpoch,
      'expectedDeliveryDate': expectedDeliveryDate.millisecondsSinceEpoch,
      'actualDeliveryDate': actualDeliveryDate?.millisecondsSinceEpoch,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'shippingCost': shippingCost,
      'discount': discount,
      'total': total,
      'notes': notes,
      'internalNotes': internalNotes,
      'createdBy': createdBy,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'receivedBy': receivedBy,
      'receivedAt': receivedAt?.millisecondsSinceEpoch,
      'attachments': attachments,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'isDeleted': isDeleted,
    };
  }

  // Create from Map (Firebase)
  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'],
      orderNumber: map['orderNumber'],
      supplierId: map['supplierId'],
      supplierName: map['supplierName'],
      items: (map['items'] as List).map((item) => PurchaseOrderItem.fromMap(item)).toList(),
      status: PurchaseOrderStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => PurchaseOrderStatus.draft,
      ),
      orderDate: DateTime.fromMillisecondsSinceEpoch(map['orderDate']),
      expectedDeliveryDate: DateTime.fromMillisecondsSinceEpoch(map['expectedDeliveryDate']),
      actualDeliveryDate: map['actualDeliveryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['actualDeliveryDate'])
          : null,
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      taxRate: map['taxRate']?.toDouble() ?? 0.0,
      taxAmount: map['taxAmount']?.toDouble() ?? 0.0,
      shippingCost: map['shippingCost']?.toDouble() ?? 0.0,
      discount: map['discount']?.toDouble() ?? 0.0,
      total: map['total']?.toDouble() ?? 0.0,
      notes: map['notes'],
      internalNotes: map['internalNotes'],
      createdBy: map['createdBy'],
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'])
          : null,
      receivedBy: map['receivedBy'],
      receivedAt: map['receivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['receivedAt'])
          : null,
      attachments: List<String>.from(map['attachments'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      deviceId: map['deviceId'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // Calculate totals
  void calculateTotals() {
    subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    taxAmount = (subtotal - discount) * taxRate;
    total = subtotal + taxAmount + shippingCost - discount;
    updatedAt = DateTime.now();
  }

  // Copy with method for updates
  PurchaseOrder copyWith({
    String? supplierId,
    String? supplierName,
    List<PurchaseOrderItem>? items,
    PurchaseOrderStatus? status,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    DateTime? actualDeliveryDate,
    double? taxRate,
    double? shippingCost,
    double? discount,
    String? notes,
    String? internalNotes,
    String? approvedBy,
    DateTime? approvedAt,
    String? receivedBy,
    DateTime? receivedAt,
    List<String>? attachments,
    bool? isSynced,
    bool? isDeleted,
  }) {
    final newOrder = PurchaseOrder(
      id: id,
      orderNumber: orderNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
      taxRate: taxRate ?? this.taxRate,
      shippingCost: shippingCost ?? this.shippingCost,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      createdBy: createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      receivedBy: receivedBy ?? this.receivedBy,
      receivedAt: receivedAt ?? this.receivedAt,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? false,
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
    
    newOrder.calculateTotals();
    return newOrder;
  }

  // Helper methods
  bool get isOverdue {
    return status != PurchaseOrderStatus.received &&
           DateTime.now().isAfter(expectedDeliveryDate);
  }

  bool get canBeApproved {
    return status == PurchaseOrderStatus.draft && items.isNotEmpty;
  }

  bool get canBeReceived {
    return status == PurchaseOrderStatus.ordered;
  }

  int get daysUntilExpected {
    return expectedDeliveryDate.difference(DateTime.now()).inDays;
  }

  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  @override
  String toString() {
    return 'PurchaseOrder(id: $id, orderNumber: $orderNumber, status: $status)';
  }
}

@HiveType(typeId: 10)
class PurchaseOrderItem extends HiveObject {
  @HiveField(0)
  String productId;

  @HiveField(1)
  String productName;

  @HiveField(2)
  String? productSku;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  int? receivedQuantity;

  @HiveField(5)
  double unitCost;

  @HiveField(6)
  double total;

  @HiveField(7)
  String? notes;

  PurchaseOrderItem({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantity,
    this.receivedQuantity,
    required this.unitCost,
    required this.total,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'quantity': quantity,
      'receivedQuantity': receivedQuantity,
      'unitCost': unitCost,
      'total': total,
      'notes': notes,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      productId: map['productId'],
      productName: map['productName'],
      productSku: map['productSku'],
      quantity: map['quantity'],
      receivedQuantity: map['receivedQuantity'],
      unitCost: map['unitCost']?.toDouble(),
      total: map['total']?.toDouble(),
      notes: map['notes'],
    );
  }

  bool get isFullyReceived {
    return receivedQuantity != null && receivedQuantity! >= quantity;
  }

  bool get isPartiallyReceived {
    return receivedQuantity != null && receivedQuantity! > 0 && receivedQuantity! < quantity;
  }

  int get pendingQuantity {
    return quantity - (receivedQuantity ?? 0);
  }
}

@HiveType(typeId: 11)
enum PurchaseOrderStatus {
  @HiveField(0)
  draft,
  @HiveField(1)
  pending, // Waiting for approval
  @HiveField(2)
  approved,
  @HiveField(3)
  ordered, // Sent to supplier
  @HiveField(4)
  partiallyReceived,
  @HiveField(5)
  received,
  @HiveField(6)
  cancelled,
  @HiveField(7)
  rejected,
}

extension PurchaseOrderStatusExtension on PurchaseOrderStatus {
  String get displayName {
    switch (this) {
      case PurchaseOrderStatus.draft:
        return 'Draft';
      case PurchaseOrderStatus.pending:
        return 'Pending Approval';
      case PurchaseOrderStatus.approved:
        return 'Approved';
      case PurchaseOrderStatus.ordered:
        return 'Ordered';
      case PurchaseOrderStatus.partiallyReceived:
        return 'Partially Received';
      case PurchaseOrderStatus.received:
        return 'Received';
      case PurchaseOrderStatus.cancelled:
        return 'Cancelled';
      case PurchaseOrderStatus.rejected:
        return 'Rejected';
    }
  }

  String get description {
    switch (this) {
      case PurchaseOrderStatus.draft:
        return 'Order being created';
      case PurchaseOrderStatus.pending:
        return 'Awaiting manager approval';
      case PurchaseOrderStatus.approved:
        return 'Approved, ready to send';
      case PurchaseOrderStatus.ordered:
        return 'Sent to supplier';
      case PurchaseOrderStatus.partiallyReceived:
        return 'Some items received';
      case PurchaseOrderStatus.received:
        return 'All items received';
      case PurchaseOrderStatus.cancelled:
        return 'Order cancelled';
      case PurchaseOrderStatus.rejected:
        return 'Order rejected';
    }
  }

  bool get isActive {
    return this != PurchaseOrderStatus.cancelled && 
           this != PurchaseOrderStatus.rejected &&
           this != PurchaseOrderStatus.received;
  }

  bool get isEditable {
    return this == PurchaseOrderStatus.draft;
  }
}