import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'inventory_change.g.dart';

@HiveType(typeId: 4)
class InventoryChange extends Equatable {
  @HiveField(0)
  final String id; // uuid

  @HiveField(1)
  final String productId;

  @HiveField(2)
  final int delta; // positive or negative

  @HiveField(3)
  final String reason; // sale, adjustment, return, damage

  @HiveField(4)
  final DateTime createdAt;

  const InventoryChange({
    required this.id,
    required this.productId,
    required this.delta,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'delta': delta,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InventoryChange.fromJson(Map<String, dynamic> json) => InventoryChange(
        id: json['id'] as String,
        productId: json['productId'] as String,
        delta: (json['delta'] as num).toInt(),
        reason: json['reason'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, productId, delta, reason, createdAt];
}