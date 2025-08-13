import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'sale.g.dart';

@HiveType(typeId: 2)
class SaleItem extends Equatable {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final double unitPrice;

  @HiveField(4)
  final double discount; // per item discount amount

  const SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
  });

  double get lineSubtotal => unitPrice * quantity;
  double get lineTotal => (unitPrice * quantity) - discount;

  SaleItem copyWith({int? quantity, double? unitPrice, double? discount}) =>
      SaleItem(
        productId: productId,
        name: name,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discount': discount,
      };

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productId: json['productId'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  List<Object?> get props => [productId, name, quantity, unitPrice, discount];
}

@HiveType(typeId: 3)
class Sale extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<SaleItem> items;

  @HiveField(2)
  final double discount; // order-level discount amount

  @HiveField(3)
  final double taxRatePercent;

  @HiveField(4)
  final double cashPaid;

  @HiveField(5)
  final double cardPaid;

  @HiveField(6)
  final double mobileMoneyPaid;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  const Sale({
    required this.id,
    required this.items,
    required this.discount,
    required this.taxRatePercent,
    required this.cashPaid,
    required this.cardPaid,
    required this.mobileMoneyPaid,
    required this.createdAt,
    required this.updatedAt,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineSubtotal) - discount;
  double get tax => subtotal * (taxRatePercent / 100.0);
  double get total => subtotal + tax;
  double get paidTotal => cashPaid + cardPaid + mobileMoneyPaid;

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'discount': discount,
        'taxRatePercent': taxRatePercent,
        'cashPaid': cashPaid,
        'cardPaid': cardPaid,
        'mobileMoneyPaid': mobileMoneyPaid,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        items: (json['items'] as List).map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        discount: (json['discount'] as num).toDouble(),
        taxRatePercent: (json['taxRatePercent'] as num).toDouble(),
        cashPaid: (json['cashPaid'] as num).toDouble(),
        cardPaid: (json['cardPaid'] as num).toDouble(),
        mobileMoneyPaid: (json['mobileMoneyPaid'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  List<Object?> get props => [id, items, discount, taxRatePercent, cashPaid, cardPaid, mobileMoneyPaid, createdAt, updatedAt];
}