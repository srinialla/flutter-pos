import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'supplier.g.dart';

@HiveType(typeId: 6)
class Supplier extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? contactPerson;

  @HiveField(3)
  String? email;

  @HiveField(4)
  String? phone;

  @HiveField(5)
  String? address;

  @HiveField(6)
  String? city;

  @HiveField(7)
  String? postalCode;

  @HiveField(8)
  String? country;

  @HiveField(9)
  String? taxNumber;

  @HiveField(10)
  String? website;

  @HiveField(11)
  List<String> itemsSupplied; // Product categories or specific items

  @HiveField(12)
  PaymentTerms paymentTerms;

  @HiveField(13)
  int leadTimeDays;

  @HiveField(14)
  double minimumOrderAmount;

  @HiveField(15)
  SupplierStatus status;

  @HiveField(16)
  double rating; // 1-5 star rating

  @HiveField(17)
  DateTime createdAt;

  @HiveField(18)
  DateTime updatedAt;

  @HiveField(19)
  bool isSynced;

  @HiveField(20)
  String? deviceId;

  @HiveField(21)
  bool isDeleted;

  @HiveField(22)
  String? notes;

  @HiveField(23)
  int totalPurchaseOrders;

  @HiveField(24)
  double totalPurchaseValue;

  @HiveField(25)
  DateTime? lastOrderDate;

  Supplier({
    String? id,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.taxNumber,
    this.website,
    List<String>? itemsSupplied,
    this.paymentTerms = PaymentTerms.net30,
    this.leadTimeDays = 7,
    this.minimumOrderAmount = 0.0,
    this.status = SupplierStatus.active,
    this.rating = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.deviceId,
    this.isDeleted = false,
    this.notes,
    this.totalPurchaseOrders = 0,
    this.totalPurchaseValue = 0.0,
    this.lastOrderDate,
  })  : id = id ?? const Uuid().v4(),
        itemsSupplied = itemsSupplied ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'taxNumber': taxNumber,
      'website': website,
      'itemsSupplied': itemsSupplied,
      'paymentTerms': paymentTerms.toString(),
      'leadTimeDays': leadTimeDays,
      'minimumOrderAmount': minimumOrderAmount,
      'status': status.toString(),
      'rating': rating,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'isDeleted': isDeleted,
      'notes': notes,
      'totalPurchaseOrders': totalPurchaseOrders,
      'totalPurchaseValue': totalPurchaseValue,
      'lastOrderDate': lastOrderDate?.millisecondsSinceEpoch,
    };
  }

  // Create from Map (Firebase)
  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      contactPerson: map['contactPerson'],
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      city: map['city'],
      postalCode: map['postalCode'],
      country: map['country'],
      taxNumber: map['taxNumber'],
      website: map['website'],
      itemsSupplied: List<String>.from(map['itemsSupplied'] ?? []),
      paymentTerms: PaymentTerms.values.firstWhere(
        (e) => e.toString() == map['paymentTerms'],
        orElse: () => PaymentTerms.net30,
      ),
      leadTimeDays: map['leadTimeDays'] ?? 7,
      minimumOrderAmount: map['minimumOrderAmount']?.toDouble() ?? 0.0,
      status: SupplierStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SupplierStatus.active,
      ),
      rating: map['rating']?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      deviceId: map['deviceId'],
      isDeleted: map['isDeleted'] ?? false,
      notes: map['notes'],
      totalPurchaseOrders: map['totalPurchaseOrders'] ?? 0,
      totalPurchaseValue: map['totalPurchaseValue']?.toDouble() ?? 0.0,
      lastOrderDate: map['lastOrderDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastOrderDate'])
          : null,
    );
  }

  // Copy with method for updates
  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? taxNumber,
    String? website,
    List<String>? itemsSupplied,
    PaymentTerms? paymentTerms,
    int? leadTimeDays,
    double? minimumOrderAmount,
    SupplierStatus? status,
    double? rating,
    bool? isSynced,
    bool? isDeleted,
    String? notes,
    int? totalPurchaseOrders,
    double? totalPurchaseValue,
    DateTime? lastOrderDate,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      taxNumber: taxNumber ?? this.taxNumber,
      website: website ?? this.website,
      itemsSupplied: itemsSupplied ?? this.itemsSupplied,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? false,
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
      notes: notes ?? this.notes,
      totalPurchaseOrders: totalPurchaseOrders ?? this.totalPurchaseOrders,
      totalPurchaseValue: totalPurchaseValue ?? this.totalPurchaseValue,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
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

  String get displayContact {
    final parts = <String>[];
    if (contactPerson?.isNotEmpty == true) parts.add(contactPerson!);
    if (email?.isNotEmpty == true) parts.add(email!);
    if (phone?.isNotEmpty == true) parts.add(phone!);
    return parts.join(' • ');
  }

  DateTime get expectedDeliveryDate {
    return DateTime.now().add(Duration(days: leadTimeDays));
  }

  @override
  String toString() {
    return 'Supplier(id: $id, name: $name, status: $status)';
  }
}

@HiveType(typeId: 7)
enum PaymentTerms {
  @HiveField(0)
  cod, // Cash on Delivery
  @HiveField(1)
  net15, // Net 15 days
  @HiveField(2)
  net30, // Net 30 days
  @HiveField(3)
  net45, // Net 45 days
  @HiveField(4)
  net60, // Net 60 days
  @HiveField(5)
  prepaid, // Prepaid
}

@HiveType(typeId: 8)
enum SupplierStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  inactive,
  @HiveField(2)
  pending,
  @HiveField(3)
  blocked,
}

extension PaymentTermsExtension on PaymentTerms {
  String get displayName {
    switch (this) {
      case PaymentTerms.cod:
        return 'Cash on Delivery';
      case PaymentTerms.net15:
        return 'Net 15 Days';
      case PaymentTerms.net30:
        return 'Net 30 Days';
      case PaymentTerms.net45:
        return 'Net 45 Days';
      case PaymentTerms.net60:
        return 'Net 60 Days';
      case PaymentTerms.prepaid:
        return 'Prepaid';
    }
  }

  int get days {
    switch (this) {
      case PaymentTerms.cod:
        return 0;
      case PaymentTerms.net15:
        return 15;
      case PaymentTerms.net30:
        return 30;
      case PaymentTerms.net45:
        return 45;
      case PaymentTerms.net60:
        return 60;
      case PaymentTerms.prepaid:
        return -1; // Negative indicates prepayment
    }
  }
}

extension SupplierStatusExtension on SupplierStatus {
  String get displayName {
    switch (this) {
      case SupplierStatus.active:
        return 'Active';
      case SupplierStatus.inactive:
        return 'Inactive';
      case SupplierStatus.pending:
        return 'Pending';
      case SupplierStatus.blocked:
        return 'Blocked';
    }
  }

  String get description {
    switch (this) {
      case SupplierStatus.active:
        return 'Available for new orders';
      case SupplierStatus.inactive:
        return 'Not currently accepting orders';
      case SupplierStatus.pending:
        return 'Awaiting approval';
      case SupplierStatus.blocked:
        return 'Blocked due to issues';
    }
  }
}