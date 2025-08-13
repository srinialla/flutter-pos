import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 1)
class Product extends Equatable {
  @HiveField(0)
  final String id; // uuid or manual

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? barcode; // EAN-13, UPC-A, Code 128, QR, etc.

  @HiveField(4)
  final double price; // selling price

  @HiveField(5)
  final double? cost; // optional

  @HiveField(6)
  final String? category;

  @HiveField(7)
  final int stockQuantity;

  @HiveField(8)
  final String? imageBase64; // optional

  @HiveField(9)
  final DateTime updatedAt; // for sync resolution

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    required this.updatedAt,
    this.description,
    this.barcode,
    this.cost,
    this.category,
    this.imageBase64,
  });

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? barcode,
    double? price,
    double? cost,
    String? category,
    int? stockQuantity,
    String? imageBase64,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      category: category ?? this.category,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageBase64: imageBase64 ?? this.imageBase64,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'barcode': barcode,
        'price': price,
        'cost': cost,
        'category': category,
        'stockQuantity': stockQuantity,
        'imageBase64': imageBase64,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        barcode: json['barcode'] as String?,
        price: (json['price'] as num).toDouble(),
        cost: (json['cost'] as num?)?.toDouble(),
        category: json['category'] as String?,
        stockQuantity: (json['stockQuantity'] as num).toInt(),
        imageBase64: json['imageBase64'] as String?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  List<Object?> get props => [id, name, barcode, price, cost, category, stockQuantity, updatedAt, imageBase64, description];
}