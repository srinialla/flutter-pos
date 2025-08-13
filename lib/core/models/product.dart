import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? barcode;

  @HiveField(4)
  double price;

  @HiveField(5)
  double? cost;

  @HiveField(6)
  String category;

  @HiveField(7)
  int stockQuantity;

  @HiveField(8)
  String? imageBase64;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  bool isSynced;

  @HiveField(12)
  String? deviceId;

  @HiveField(13)
  bool isDeleted;

  Product({
    String? id,
    required this.name,
    this.description,
    this.barcode,
    required this.price,
    this.cost,
    required this.category,
    required this.stockQuantity,
    this.imageBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.deviceId,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'barcode': barcode,
      'price': price,
      'cost': cost,
      'category': category,
      'stockQuantity': stockQuantity,
      'imageBase64': imageBase64,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'isDeleted': isDeleted,
    };
  }

  // Create from Map (Firebase)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      barcode: map['barcode'],
      price: map['price']?.toDouble(),
      cost: map['cost']?.toDouble(),
      category: map['category'],
      stockQuantity: map['stockQuantity'],
      imageBase64: map['imageBase64'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      deviceId: map['deviceId'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // Copy with method for updates
  Product copyWith({
    String? name,
    String? description,
    String? barcode,
    double? price,
    double? cost,
    String? category,
    int? stockQuantity,
    String? imageBase64,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      category: category ?? this.category,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageBase64: imageBase64 ?? this.imageBase64,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? false,
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, stock: $stockQuantity)';
  }
}