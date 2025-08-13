import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/receipt_config.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../utils/platform_utils.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';

class PrinterService {
  static PrinterService? _instance;
  static PrinterService get instance => _instance ??= PrinterService._();
  PrinterService._();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  bool _isInitialized = false;
  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _availableDevices = [];

  bool get isInitialized => _isInitialized;
  bool get isConnected => _connectedDevice != null;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get availableDevices => _availableDevices;

  Future<void> initialize() async {
    if (_isInitialized || !PlatformUtils.isMobile) return;

    try {
      // Request Bluetooth permissions
      if (PlatformUtils.isAndroid) {
        final permissions = [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ];

        for (final permission in permissions) {
          final status = await permission.request();
          if (status != PermissionStatus.granted) {
            debugPrint('Bluetooth permission denied: $permission');
          }
        }
      }

      _isInitialized = true;
      debugPrint('Printer service initialized');

      await _analytics.trackEvent('printer_service_initialized', {
        'platform': PlatformUtils.getPlatformName(),
      });
    } catch (e) {
      debugPrint('Printer service initialization failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'printer_init_failed');
    }
  }

  // Bluetooth Device Management
  Future<List<BluetoothDevice>> scanForDevices() async {
    if (!_isInitialized || !PlatformUtils.isMobile) return [];

    try {
      final isBluetoothOn = await _bluetooth.isOn;
      if (!isBluetoothOn!) {
        throw Exception('Bluetooth is not enabled');
      }

      _availableDevices = await _bluetooth.getBondedDevices();
      
      await _analytics.trackEvent('bluetooth_scan_completed', {
        'devices_found': _availableDevices.length,
      });

      return _availableDevices;
    } catch (e) {
      debugPrint('Bluetooth scan failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'bluetooth_scan_failed');
      return [];
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (!_isInitialized) return false;

    try {
      final isConnected = await _bluetooth.isConnected;
      if (isConnected!) {
        await _bluetooth.disconnect();
      }

      await _bluetooth.connect(device);
      _connectedDevice = device;

      // Store connected device for auto-reconnection
      await _localStorage.setSetting('printer_device_address', device.address);
      await _localStorage.setSetting('printer_device_name', device.name);

      await _analytics.trackEvent('printer_connected', {
        'device_name': device.name,
        'device_address': device.address,
      });

      return true;
    } catch (e) {
      debugPrint('Bluetooth connection failed: $e');
      await _analytics.recordError(e, StackTrace.current, 'bluetooth_connect_failed');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (!_isInitialized) return;

    try {
      await _bluetooth.disconnect();
      _connectedDevice = null;

      await _analytics.trackEvent('printer_disconnected');
    } catch (e) {
      debugPrint('Bluetooth disconnect failed: $e');
    }
  }

  Future<bool> testConnection() async {
    if (!isConnected) return false;

    try {
      await _bluetooth.printNewLine();
      await _bluetooth.printCustom("Test Print", 1, 1);
      await _bluetooth.printNewLine();
      await _bluetooth.paperCut();
      return true;
    } catch (e) {
      debugPrint('Printer test failed: $e');
      return false;
    }
  }

  // Auto-reconnection
  Future<void> autoReconnect() async {
    if (!_isInitialized || isConnected) return;

    final deviceAddress = _localStorage.getSetting<String>('printer_device_address');
    if (deviceAddress == null) return;

    try {
      final devices = await scanForDevices();
      final savedDevice = devices.firstWhere(
        (device) => device.address == deviceAddress,
        orElse: () => throw Exception('Saved printer not found'),
      );

      await connectToDevice(savedDevice);
    } catch (e) {
      debugPrint('Auto-reconnection failed: $e');
    }
  }

  // Receipt Printing
  Future<PrintResult> printReceipt(
    Sale sale,
    ReceiptConfig config, {
    Customer? customer,
    String? cashierName,
  }) async {
    try {
      if (config.printerConnection == PrinterConnection.bluetooth) {
        return await _printBluetoothReceipt(sale, config, customer: customer, cashierName: cashierName);
      } else if (config.printerConnection == PrinterConnection.none) {
        return await _generateReceiptPreview(sale, config, customer: customer, cashierName: cashierName);
      } else {
        return await _printNetworkReceipt(sale, config, customer: customer, cashierName: cashierName);
      }
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'receipt_print_failed');
      return PrintResult(
        success: false,
        message: 'Print failed: $e',
      );
    }
  }

  Future<PrintResult> _printBluetoothReceipt(
    Sale sale,
    ReceiptConfig config, {
    Customer? customer,
    String? cashierName,
  }) async {
    if (!isConnected) {
      await autoReconnect();
      if (!isConnected) {
        return PrintResult(
          success: false,
          message: 'Printer not connected',
        );
      }
    }

    try {
      final receiptText = _generateReceiptText(sale, config, customer: customer, cashierName: cashierName);
      
      // Print multiple copies if configured
      for (int i = 0; i < config.copies; i++) {
        await _printTextReceipt(receiptText, config);
        
        if (i < config.copies - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Open cash drawer if configured
      if (config.openCashDrawer) {
        await _openCashDrawer();
      }

      await _analytics.trackEvent('receipt_printed', {
        'printer_type': 'bluetooth',
        'copies': config.copies,
        'total_amount': sale.total,
      });

      return PrintResult(
        success: true,
        message: 'Receipt printed successfully',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        message: 'Bluetooth print failed: $e',
      );
    }
  }

  Future<void> _printTextReceipt(String receiptText, ReceiptConfig config) async {
    final lines = receiptText.split('\n');
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        await _bluetooth.printNewLine();
        continue;
      }

      // Handle different line types
      if (line.startsWith('===') || line.startsWith('---')) {
        await _bluetooth.printCustom(line, 1, 1);
      } else if (line.contains('TOTAL:') || line.contains('RECEIPT')) {
        await _bluetooth.printCustom(line, 2, 1); // Size 2, Center aligned
      } else {
        await _bluetooth.printCustom(line, 1, 0); // Size 1, Left aligned
      }
    }

    // Cut paper
    await _bluetooth.paperCut();
  }

  Future<void> _openCashDrawer() async {
    try {
      // ESC/POS command to open cash drawer
      final List<int> bytes = [27, 112, 0, 25, 250]; // ESC p 0 25 250
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('Failed to open cash drawer: $e');
    }
  }

  Future<PrintResult> _printNetworkReceipt(
    Sale sale,
    ReceiptConfig config, {
    Customer? customer,
    String? cashierName,
  }) async {
    try {
      // Generate PDF receipt
      final pdf = await _generatePdfReceipt(sale, config, customer: customer, cashierName: cashierName);
      
      // Print PDF using system printer
      await Printing.layoutPdf(onLayout: (_) => pdf.save());

      await _analytics.trackEvent('receipt_printed', {
        'printer_type': 'network',
        'total_amount': sale.total,
      });

      return PrintResult(
        success: true,
        message: 'Receipt sent to printer',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        message: 'Network print failed: $e',
      );
    }
  }

  Future<PrintResult> _generateReceiptPreview(
    Sale sale,
    ReceiptConfig config, {
    Customer? customer,
    String? cashierName,
  }) async {
    try {
      final receiptText = _generateReceiptText(sale, config, customer: customer, cashierName: cashierName);
      
      return PrintResult(
        success: true,
        message: 'Receipt preview generated',
        receiptText: receiptText,
      );
    } catch (e) {
      return PrintResult(
        success: false,
        message: 'Preview generation failed: $e',
      );
    }
  }

  // Receipt Generation
  String _generateReceiptText(
    Sale sale,
    ReceiptConfig config, {
    Customer? customer,
    String? cashierName,
  }) {
    final buffer = StringBuffer();
    final width = config.paperWidth;

    // Header
    if (config.headerText?.isNotEmpty == true) {
      buffer.writeln(_centerText(config.headerText!, width));
      buffer.writeln(_generateSeparator(width));
    }

    // Business Information
    buffer.writeln(_centerText(config.businessName, width));
    if (config.businessAddress?.isNotEmpty == true) {
      buffer.writeln(_centerText(config.businessAddress!, width));
    }
    if (config.businessPhone?.isNotEmpty == true) {
      buffer.writeln(_centerText(config.businessPhone!, width));
    }
    if (config.businessEmail?.isNotEmpty == true) {
      buffer.writeln(_centerText(config.businessEmail!, width));
    }
    if (config.taxNumber?.isNotEmpty == true) {
      buffer.writeln(_centerText('Tax ID: ${config.taxNumber}', width));
    }

    buffer.writeln(_generateSeparator(width));

    // Receipt Type and Number
    final receiptTitle = config.receiptType.displayName.toUpperCase();
    buffer.writeln(_centerText(receiptTitle, width));
    buffer.writeln(_centerText('${sale.id.substring(0, 8)}', width));

    // Date and Time
    if (config.showDateTime) {
      final dateTime = sale.createdAt;
      buffer.writeln(_centerText('${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}', width));
    }

    // Cashier
    if (config.showCashierInfo && cashierName?.isNotEmpty == true) {
      buffer.writeln(_centerText('Cashier: $cashierName', width));
    }

    // Customer
    if (config.showCustomerInfo && customer != null) {
      buffer.writeln(_centerText('Customer: ${customer.name}', width));
    }

    buffer.writeln(_generateSeparator(width));

    // Items
    for (final item in sale.items) {
      buffer.writeln(item.productName);
      
      final qtyPrice = '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}';
      final total = '\$${item.total.toStringAsFixed(2)}';
      final line = '$qtyPrice${' ' * (width - qtyPrice.length - total.length)}$total';
      buffer.writeln(line);
      
      if (item.discount > 0) {
        buffer.writeln('  Discount: -\$${item.discount.toStringAsFixed(2)}');
      }
    }

    buffer.writeln(_generateSeparator(width));

    // Totals
    if (config.showSubtotal) {
      final subtotalLine = _formatTotalLine('Subtotal:', sale.subtotal, width);
      buffer.writeln(subtotalLine);
    }

    if (config.showDiscount && sale.discount > 0) {
      final discountLine = _formatTotalLine('Discount:', -sale.discount, width);
      buffer.writeln(discountLine);
    }

    if (config.showTax && sale.taxAmount > 0) {
      final taxLine = _formatTotalLine('Tax (${(sale.taxRate * 100).toStringAsFixed(1)}%):', sale.taxAmount, width);
      buffer.writeln(taxLine);
    }

    buffer.writeln(_generateSeparator(width, '='));

    if (config.showTotal) {
      final totalLine = _formatTotalLine('TOTAL:', sale.total, width);
      buffer.writeln(totalLine);
    }

    buffer.writeln(_generateSeparator(width, '='));

    // Payment Information
    if (config.showPaymentMethod) {
      final paymentMethod = sale.paymentMethod.toString().split('.').last.toUpperCase();
      buffer.writeln('Payment: $paymentMethod');
    }

    if (config.showAmountPaid) {
      buffer.writeln('Amount Paid: \$${sale.amountPaid.toStringAsFixed(2)}');
    }

    if (config.showChange && sale.change > 0) {
      buffer.writeln('Change: \$${sale.change.toStringAsFixed(2)}');
    }

    buffer.writeln(_generateSeparator(width));

    // Footer
    if (config.thankYouMessage?.isNotEmpty == true) {
      buffer.writeln(_centerText(config.thankYouMessage!, width));
    }

    if (config.footerText?.isNotEmpty == true) {
      buffer.writeln(_centerText(config.footerText!, width));
    }

    // Custom fields
    for (final field in config.customFields) {
      if (field.isNotEmpty) {
        buffer.writeln(_centerText(field, width));
      }
    }

    return buffer.toString();
  }

  Future<pw.Document> _generatePdfReceipt(
    Sale sale,
    ReceiptConfig config, {
    Customer? customer,
    String? cashierName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: config.receiptSize == ReceiptSize.a4 
            ? PdfPageFormat.a4 
            : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      config.businessName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (config.businessAddress?.isNotEmpty == true)
                      pw.Text(config.businessAddress!),
                    if (config.businessPhone?.isNotEmpty == true)
                      pw.Text(config.businessPhone!),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              
              // Receipt details
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      config.receiptType.displayName.toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('ID: ${sale.id.substring(0, 8)}'),
                    pw.Text('Date: ${sale.createdAt}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              
              // Items
              ...sale.items.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.productName),
                        pw.Text('${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                  pw.Text('\$${item.total.toStringAsFixed(2)}'),
                ],
              )),
              
              pw.Divider(),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('\$${sale.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              
              pw.SizedBox(height: 10),
              pw.Divider(),
              
              // Thank you message
              if (config.thankYouMessage?.isNotEmpty == true)
                pw.Center(
                  child: pw.Text(config.thankYouMessage!),
                ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // Utility methods
  String _centerText(String text, int width) {
    if (text.length >= width) return text;
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  String _generateSeparator(int width, [String char = '-']) {
    return char * width;
  }

  String _formatTotalLine(String label, double amount, int width) {
    final amountStr = '\$${amount.toStringAsFixed(2)}';
    final padding = width - label.length - amountStr.length;
    return '$label${' ' * padding}$amountStr';
  }

  // Configuration Management
  Future<ReceiptConfig> getDefaultReceiptConfig() async {
    try {
      final configs = await getAllReceiptConfigs();
      final defaultConfig = configs.firstWhere(
        (config) => config.isDefault,
        orElse: () => _createDefaultConfig(),
      );
      return defaultConfig;
    } catch (e) {
      return _createDefaultConfig();
    }
  }

  ReceiptConfig _createDefaultConfig() {
    return ReceiptConfig(
      name: 'Default Receipt',
      isDefault: true,
      businessName: 'Your Business Name',
      receiptSize: ReceiptSize.mm80,
      paperWidth: 48,
    );
  }

  Future<List<ReceiptConfig>> getAllReceiptConfigs() async {
    // This would typically load from local storage
    // For now, return default config
    return [_createDefaultConfig()];
  }

  Future<void> saveReceiptConfig(ReceiptConfig config) async {
    // Save to local storage and sync to Firebase
    await _localStorage.setSetting('receipt_config_${config.id}', config.toMap());
    
    if (config.isDefault) {
      await _localStorage.setSetting('default_receipt_config_id', config.id);
    }
  }

  // Cleanup
  Future<void> dispose() async {
    if (isConnected) {
      await disconnect();
    }
    _isInitialized = false;
  }
}

class PrintResult {
  final bool success;
  final String message;
  final String? receiptText;
  final Uint8List? pdfData;

  PrintResult({
    required this.success,
    required this.message,
    this.receiptText,
    this.pdfData,
  });
}