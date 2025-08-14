import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'customer.g.dart';

@HiveType(typeId: 4)
class Customer extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? email;

  @HiveField(3)
  String? phone;

  @HiveField(4)
  String? address;

  @HiveField(5)
  String? city;

  @HiveField(6)
  String? postalCode;

  @HiveField(7)
  String? country;

  @HiveField(8)
  String? taxNumber;

  @HiveField(9)
  CustomerType customerType;

  @HiveField(10)
  double creditLimit;

  @HiveField(11)
  double currentBalance;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  DateTime updatedAt;

  @HiveField(14)
  bool isSynced;

  @HiveField(15)
  String? deviceId;

  @HiveField(16)
  bool isDeleted;

  @HiveField(17)
  String? notes;

  @HiveField(18)
  int totalPurchases;

  @HiveField(19)
  double totalSpent;

  @HiveField(20)
  DateTime? lastPurchaseDate;

  Customer({
    String? id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.taxNumber,
    this.customerType = CustomerType.retail,
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.deviceId,
    this.isDeleted = false,
    this.notes,
    this.totalPurchases = 0,
    this.totalSpent = 0.0,
    this.lastPurchaseDate,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'taxNumber': taxNumber,
      'customerType': customerType.toString(),
      'creditLimit': creditLimit,
      'currentBalance': currentBalance,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'isDeleted': isDeleted,
      'notes': notes,
      'totalPurchases': totalPurchases,
      'totalSpent': totalSpent,
      'lastPurchaseDate': lastPurchaseDate?.millisecondsSinceEpoch,
    };
  }

  // Create from Map (Firebase)
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      city: map['city'],
      postalCode: map['postalCode'],
      country: map['country'],
      taxNumber: map['taxNumber'],
      customerType: CustomerType.values.firstWhere(
        (e) => e.toString() == map['customerType'],
        orElse: () => CustomerType.retail,
      ),
      creditLimit: map['creditLimit']?.toDouble() ?? 0.0,
      currentBalance: map['currentBalance']?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      deviceId: map['deviceId'],
      isDeleted: map['isDeleted'] ?? false,
      notes: map['notes'],
      totalPurchases: map['totalPurchases'] ?? 0,
      totalSpent: map['totalSpent']?.toDouble() ?? 0.0,
      lastPurchaseDate: map['lastPurchaseDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastPurchaseDate'])
          : null,
    );
  }

  // Copy with method for updates
  Customer copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? taxNumber,
    CustomerType? customerType,
    double? creditLimit,
    double? currentBalance,
    bool? isSynced,
    bool? isDeleted,
    String? notes,
    int? totalPurchases,
    double? totalSpent,
    DateTime? lastPurchaseDate,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      taxNumber: taxNumber ?? this.taxNumber,
      customerType: customerType ?? this.customerType,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? false,
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
      notes: notes ?? this.notes,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSpent: totalSpent ?? this.totalSpent,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
    );
  }

  String get fullAddress {
    final parts = <String>[];
    if (address?.isNotEmpty == true) parts.add(address!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (postalCode?.isNotEmpty == true) parts.add(postalCode!);
    if (country?.isNotEmpty == true) parts.add(country!);
    return parts.join(', ');
  }

  String get displayName {
    if (email?.isNotEmpty == true) {
      return '$name ($email)';
    }
    return name;
  }

  @override
  String toString() {
    return 'Customer(id: $id, name: $name, type: $customerType)';
  }
}

@HiveType(typeId: 5)
enum CustomerType {
  @HiveField(0)
  retail,
  @HiveField(1)
  wholesale,
  @HiveField(2)
  vip,
  @HiveField(3)
  corporate,
}

extension CustomerTypeExtension on CustomerType {
  String get displayName {
    switch (this) {
      case CustomerType.retail:
        return 'Retail';
      case CustomerType.wholesale:
        return 'Wholesale';
      case CustomerType.vip:
        return 'VIP';
      case CustomerType.corporate:
        return 'Corporate';
    }
  }

  String get description {
    switch (this) {
      case CustomerType.retail:
        return 'Individual customers';
      case CustomerType.wholesale:
        return 'Bulk purchase customers';
      case CustomerType.vip:
        return 'Premium customers';
      case CustomerType.corporate:
        return 'Business customers';
    }
  }
}