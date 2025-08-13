import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'receipt_config.g.dart';

@HiveType(typeId: 12)
class ReceiptConfig extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isDefault;

  @HiveField(3)
  ReceiptType receiptType;

  // Business Information
  @HiveField(4)
  String businessName;

  @HiveField(5)
  String? businessAddress;

  @HiveField(6)
  String? businessPhone;

  @HiveField(7)
  String? businessEmail;

  @HiveField(8)
  String? businessWebsite;

  @HiveField(9)
  String? taxNumber;

  @HiveField(10)
  String? registrationNumber;

  // Receipt Layout
  @HiveField(11)
  ReceiptSize receiptSize;

  @HiveField(12)
  int paperWidth; // in characters or mm

  @HiveField(13)
  String logoPath; // Path to logo image

  @HiveField(14)
  bool showLogo;

  @HiveField(15)
  HeaderAlignment headerAlignment;

  @HiveField(16)
  bool showQRCode;

  @HiveField(17)
  bool showBarcode;

  // Content Settings
  @HiveField(18)
  bool showItemCodes;

  @HiveField(19)
  bool showItemDescription;

  @HiveField(20)
  bool showUnitPrice;

  @HiveField(21)
  bool showQuantity;

  @HiveField(22)
  bool showItemTotal;

  @HiveField(23)
  bool showSubtotal;

  @HiveField(24)
  bool showTax;

  @HiveField(25)
  bool showDiscount;

  @HiveField(26)
  bool showTotal;

  @HiveField(27)
  bool showPaymentMethod;

  @HiveField(28)
  bool showAmountPaid;

  @HiveField(29)
  bool showChange;

  @HiveField(30)
  bool showCustomerInfo;

  @HiveField(31)
  bool showCashierInfo;

  @HiveField(32)
  bool showDateTime;

  // Custom Fields
  @HiveField(33)
  String? headerText;

  @HiveField(34)
  String? footerText;

  @HiveField(35)
  String? thankYouMessage;

  @HiveField(36)
  List<String> customFields;

  // Printing Settings
  @HiveField(37)
  bool autoPrint;

  @HiveField(38)
  int copies;

  @HiveField(39)
  bool openCashDrawer;

  @HiveField(40)
  PrinterConnection printerConnection;

  @HiveField(41)
  String? printerAddress; // Bluetooth address or IP

  @HiveField(42)
  String? printerName;

  // Email Settings
  @HiveField(43)
  bool enableEmailReceipts;

  @HiveField(44)
  String? emailSubject;

  @HiveField(45)
  String? emailTemplate;

  @HiveField(46)
  bool autoSendEmail;

  // Audit
  @HiveField(47)
  DateTime createdAt;

  @HiveField(48)
  DateTime updatedAt;

  @HiveField(49)
  bool isSynced;

  @HiveField(50)
  String? deviceId;

  @HiveField(51)
  bool isDeleted;

  ReceiptConfig({
    String? id,
    required this.name,
    this.isDefault = false,
    this.receiptType = ReceiptType.sale,
    required this.businessName,
    this.businessAddress,
    this.businessPhone,
    this.businessEmail,
    this.businessWebsite,
    this.taxNumber,
    this.registrationNumber,
    this.receiptSize = ReceiptSize.mm80,
    this.paperWidth = 48,
    this.logoPath = '',
    this.showLogo = false,
    this.headerAlignment = HeaderAlignment.center,
    this.showQRCode = false,
    this.showBarcode = false,
    this.showItemCodes = true,
    this.showItemDescription = true,
    this.showUnitPrice = true,
    this.showQuantity = true,
    this.showItemTotal = true,
    this.showSubtotal = true,
    this.showTax = true,
    this.showDiscount = true,
    this.showTotal = true,
    this.showPaymentMethod = true,
    this.showAmountPaid = true,
    this.showChange = true,
    this.showCustomerInfo = false,
    this.showCashierInfo = true,
    this.showDateTime = true,
    this.headerText,
    this.footerText,
    this.thankYouMessage = 'Thank you for your business!',
    List<String>? customFields,
    this.autoPrint = false,
    this.copies = 1,
    this.openCashDrawer = false,
    this.printerConnection = PrinterConnection.none,
    this.printerAddress,
    this.printerName,
    this.enableEmailReceipts = false,
    this.emailSubject,
    this.emailTemplate,
    this.autoSendEmail = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.deviceId,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        customFields = customFields ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isDefault': isDefault,
      'receiptType': receiptType.toString(),
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'businessWebsite': businessWebsite,
      'taxNumber': taxNumber,
      'registrationNumber': registrationNumber,
      'receiptSize': receiptSize.toString(),
      'paperWidth': paperWidth,
      'logoPath': logoPath,
      'showLogo': showLogo,
      'headerAlignment': headerAlignment.toString(),
      'showQRCode': showQRCode,
      'showBarcode': showBarcode,
      'showItemCodes': showItemCodes,
      'showItemDescription': showItemDescription,
      'showUnitPrice': showUnitPrice,
      'showQuantity': showQuantity,
      'showItemTotal': showItemTotal,
      'showSubtotal': showSubtotal,
      'showTax': showTax,
      'showDiscount': showDiscount,
      'showTotal': showTotal,
      'showPaymentMethod': showPaymentMethod,
      'showAmountPaid': showAmountPaid,
      'showChange': showChange,
      'showCustomerInfo': showCustomerInfo,
      'showCashierInfo': showCashierInfo,
      'showDateTime': showDateTime,
      'headerText': headerText,
      'footerText': footerText,
      'thankYouMessage': thankYouMessage,
      'customFields': customFields,
      'autoPrint': autoPrint,
      'copies': copies,
      'openCashDrawer': openCashDrawer,
      'printerConnection': printerConnection.toString(),
      'printerAddress': printerAddress,
      'printerName': printerName,
      'enableEmailReceipts': enableEmailReceipts,
      'emailSubject': emailSubject,
      'emailTemplate': emailTemplate,
      'autoSendEmail': autoSendEmail,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'isDeleted': isDeleted,
    };
  }

  // Create from Map (Firebase)
  factory ReceiptConfig.fromMap(Map<String, dynamic> map) {
    return ReceiptConfig(
      id: map['id'],
      name: map['name'],
      isDefault: map['isDefault'] ?? false,
      receiptType: ReceiptType.values.firstWhere(
        (e) => e.toString() == map['receiptType'],
        orElse: () => ReceiptType.sale,
      ),
      businessName: map['businessName'],
      businessAddress: map['businessAddress'],
      businessPhone: map['businessPhone'],
      businessEmail: map['businessEmail'],
      businessWebsite: map['businessWebsite'],
      taxNumber: map['taxNumber'],
      registrationNumber: map['registrationNumber'],
      receiptSize: ReceiptSize.values.firstWhere(
        (e) => e.toString() == map['receiptSize'],
        orElse: () => ReceiptSize.mm80,
      ),
      paperWidth: map['paperWidth'] ?? 48,
      logoPath: map['logoPath'] ?? '',
      showLogo: map['showLogo'] ?? false,
      headerAlignment: HeaderAlignment.values.firstWhere(
        (e) => e.toString() == map['headerAlignment'],
        orElse: () => HeaderAlignment.center,
      ),
      showQRCode: map['showQRCode'] ?? false,
      showBarcode: map['showBarcode'] ?? false,
      showItemCodes: map['showItemCodes'] ?? true,
      showItemDescription: map['showItemDescription'] ?? true,
      showUnitPrice: map['showUnitPrice'] ?? true,
      showQuantity: map['showQuantity'] ?? true,
      showItemTotal: map['showItemTotal'] ?? true,
      showSubtotal: map['showSubtotal'] ?? true,
      showTax: map['showTax'] ?? true,
      showDiscount: map['showDiscount'] ?? true,
      showTotal: map['showTotal'] ?? true,
      showPaymentMethod: map['showPaymentMethod'] ?? true,
      showAmountPaid: map['showAmountPaid'] ?? true,
      showChange: map['showChange'] ?? true,
      showCustomerInfo: map['showCustomerInfo'] ?? false,
      showCashierInfo: map['showCashierInfo'] ?? true,
      showDateTime: map['showDateTime'] ?? true,
      headerText: map['headerText'],
      footerText: map['footerText'],
      thankYouMessage: map['thankYouMessage'],
      customFields: List<String>.from(map['customFields'] ?? []),
      autoPrint: map['autoPrint'] ?? false,
      copies: map['copies'] ?? 1,
      openCashDrawer: map['openCashDrawer'] ?? false,
      printerConnection: PrinterConnection.values.firstWhere(
        (e) => e.toString() == map['printerConnection'],
        orElse: () => PrinterConnection.none,
      ),
      printerAddress: map['printerAddress'],
      printerName: map['printerName'],
      enableEmailReceipts: map['enableEmailReceipts'] ?? false,
      emailSubject: map['emailSubject'],
      emailTemplate: map['emailTemplate'],
      autoSendEmail: map['autoSendEmail'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      deviceId: map['deviceId'],
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  // Copy with method for updates
  ReceiptConfig copyWith({
    String? name,
    bool? isDefault,
    ReceiptType? receiptType,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? businessWebsite,
    String? taxNumber,
    String? registrationNumber,
    ReceiptSize? receiptSize,
    int? paperWidth,
    String? logoPath,
    bool? showLogo,
    HeaderAlignment? headerAlignment,
    bool? showQRCode,
    bool? showBarcode,
    bool? showItemCodes,
    bool? showItemDescription,
    bool? showUnitPrice,
    bool? showQuantity,
    bool? showItemTotal,
    bool? showSubtotal,
    bool? showTax,
    bool? showDiscount,
    bool? showTotal,
    bool? showPaymentMethod,
    bool? showAmountPaid,
    bool? showChange,
    bool? showCustomerInfo,
    bool? showCashierInfo,
    bool? showDateTime,
    String? headerText,
    String? footerText,
    String? thankYouMessage,
    List<String>? customFields,
    bool? autoPrint,
    int? copies,
    bool? openCashDrawer,
    PrinterConnection? printerConnection,
    String? printerAddress,
    String? printerName,
    bool? enableEmailReceipts,
    String? emailSubject,
    String? emailTemplate,
    bool? autoSendEmail,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return ReceiptConfig(
      id: id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      receiptType: receiptType ?? this.receiptType,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      businessEmail: businessEmail ?? this.businessEmail,
      businessWebsite: businessWebsite ?? this.businessWebsite,
      taxNumber: taxNumber ?? this.taxNumber,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      receiptSize: receiptSize ?? this.receiptSize,
      paperWidth: paperWidth ?? this.paperWidth,
      logoPath: logoPath ?? this.logoPath,
      showLogo: showLogo ?? this.showLogo,
      headerAlignment: headerAlignment ?? this.headerAlignment,
      showQRCode: showQRCode ?? this.showQRCode,
      showBarcode: showBarcode ?? this.showBarcode,
      showItemCodes: showItemCodes ?? this.showItemCodes,
      showItemDescription: showItemDescription ?? this.showItemDescription,
      showUnitPrice: showUnitPrice ?? this.showUnitPrice,
      showQuantity: showQuantity ?? this.showQuantity,
      showItemTotal: showItemTotal ?? this.showItemTotal,
      showSubtotal: showSubtotal ?? this.showSubtotal,
      showTax: showTax ?? this.showTax,
      showDiscount: showDiscount ?? this.showDiscount,
      showTotal: showTotal ?? this.showTotal,
      showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      showAmountPaid: showAmountPaid ?? this.showAmountPaid,
      showChange: showChange ?? this.showChange,
      showCustomerInfo: showCustomerInfo ?? this.showCustomerInfo,
      showCashierInfo: showCashierInfo ?? this.showCashierInfo,
      showDateTime: showDateTime ?? this.showDateTime,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      thankYouMessage: thankYouMessage ?? this.thankYouMessage,
      customFields: customFields ?? this.customFields,
      autoPrint: autoPrint ?? this.autoPrint,
      copies: copies ?? this.copies,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      printerConnection: printerConnection ?? this.printerConnection,
      printerAddress: printerAddress ?? this.printerAddress,
      printerName: printerName ?? this.printerName,
      enableEmailReceipts: enableEmailReceipts ?? this.enableEmailReceipts,
      emailSubject: emailSubject ?? this.emailSubject,
      emailTemplate: emailTemplate ?? this.emailTemplate,
      autoSendEmail: autoSendEmail ?? this.autoSendEmail,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? false,
      deviceId: deviceId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'ReceiptConfig(id: $id, name: $name, type: $receiptType)';
  }
}

@HiveType(typeId: 13)
enum ReceiptType {
  @HiveField(0)
  sale,
  @HiveField(1)
  refund,
  @HiveField(2)
  invoice,
  @HiveField(3)
  quote,
  @HiveField(4)
  purchaseOrder,
}

@HiveType(typeId: 14)
enum ReceiptSize {
  @HiveField(0)
  mm58, // 58mm thermal paper
  @HiveField(1)
  mm80, // 80mm thermal paper
  @HiveField(2)
  a4, // A4 paper
  @HiveField(3)
  letter, // US Letter paper
  @HiveField(4)
  custom,
}

@HiveType(typeId: 15)
enum HeaderAlignment {
  @HiveField(0)
  left,
  @HiveField(1)
  center,
  @HiveField(2)
  right,
}

@HiveType(typeId: 16)
enum PrinterConnection {
  @HiveField(0)
  none,
  @HiveField(1)
  bluetooth,
  @HiveField(2)
  wifi,
  @HiveField(3)
  usb,
  @HiveField(4)
  network,
}

extension ReceiptTypeExtension on ReceiptType {
  String get displayName {
    switch (this) {
      case ReceiptType.sale:
        return 'Sale Receipt';
      case ReceiptType.refund:
        return 'Refund Receipt';
      case ReceiptType.invoice:
        return 'Invoice';
      case ReceiptType.quote:
        return 'Quote';
      case ReceiptType.purchaseOrder:
        return 'Purchase Order';
    }
  }
}

extension ReceiptSizeExtension on ReceiptSize {
  String get displayName {
    switch (this) {
      case ReceiptSize.mm58:
        return '58mm Thermal';
      case ReceiptSize.mm80:
        return '80mm Thermal';
      case ReceiptSize.a4:
        return 'A4 Paper';
      case ReceiptSize.letter:
        return 'Letter Paper';
      case ReceiptSize.custom:
        return 'Custom Size';
    }
  }

  int get defaultWidth {
    switch (this) {
      case ReceiptSize.mm58:
        return 32;
      case ReceiptSize.mm80:
        return 48;
      case ReceiptSize.a4:
        return 80;
      case ReceiptSize.letter:
        return 80;
      case ReceiptSize.custom:
        return 48;
    }
  }
}

extension PrinterConnectionExtension on PrinterConnection {
  String get displayName {
    switch (this) {
      case PrinterConnection.none:
        return 'No Printer';
      case PrinterConnection.bluetooth:
        return 'Bluetooth';
      case PrinterConnection.wifi:
        return 'WiFi';
      case PrinterConnection.usb:
        return 'USB';
      case PrinterConnection.network:
        return 'Network';
    }
  }
}