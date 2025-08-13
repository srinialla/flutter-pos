import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sale.g.dart';

@HiveType(typeId: 1)
class Sale extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  List<SaleItem> items;

  @HiveField(2)
  double subtotal;

  @HiveField(3)
  double taxRate;

  @HiveField(4)
  double taxAmount;

  @HiveField(5)
  double discount;

  @HiveField(6)
  double total;

  @HiveField(7)
  PaymentMethod paymentMethod;

  @HiveField(8)
  double amountPaid;

  @HiveField(9)
  double change;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  bool isSynced;

  @HiveField(12)
  String? deviceId;

  @HiveField(13)
  String? customerId;

  @HiveField(14)
  String? notes;

  Sale({
    String? id,
    required this.items,
    required this.subtotal,
    this.taxRate = 0.0,
    required this.taxAmount,
    this.discount = 0.0,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    this.change = 0.0,
    DateTime? createdAt,
    this.isSynced = false,
    this.deviceId,
    this.customerId,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'discount': discount,
      'total': total,
      'paymentMethod': paymentMethod.toString(),
      'amountPaid': amountPaid,
      'change': change,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'customerId': customerId,
      'notes': notes,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      items: (map['items'] as List).map((item) => SaleItem.fromMap(item)).toList(),
      subtotal: map['subtotal']?.toDouble(),
      taxRate: map['taxRate']?.toDouble() ?? 0.0,
      taxAmount: map['taxAmount']?.toDouble(),
      discount: map['discount']?.toDouble() ?? 0.0,
      total: map['total']?.toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      amountPaid: map['amountPaid']?.toDouble(),
      change: map['change']?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      deviceId: map['deviceId'],
      customerId: map['customerId'],
      notes: map['notes'],
    );
  }
}

@HiveType(typeId: 2)
class SaleItem extends HiveObject {
  @HiveField(0)
  String productId;

  @HiveField(1)
  String productName;

  @HiveField(2)
  double unitPrice;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  double discount;

  @HiveField(5)
  double total;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0.0,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'discount': discount,
      'total': total,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'],
      productName: map['productName'],
      unitPrice: map['unitPrice']?.toDouble(),
      quantity: map['quantity'],
      discount: map['discount']?.toDouble() ?? 0.0,
      total: map['total']?.toDouble(),
    );
  }
}

@HiveType(typeId: 3)
enum PaymentMethod {
  @HiveField(0)
  cash,
  @HiveField(1)
  card,
  @HiveField(2)
  mobileMoney,
}