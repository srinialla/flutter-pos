import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeService {
  static BarcodeService? _instance;
  static BarcodeService get instance => _instance ??= BarcodeService._();
  BarcodeService._();

  late MobileScannerController _controller;
  bool _isInitialized = false;

  MobileScannerController get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request camera permission
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        return false;
      }

      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: [
          BarcodeFormat.qrCode,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
        ],
      );

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing barcode scanner: $e');
      return false;
    }
  }

  Future<void> startScanning() async {
    if (!_isInitialized) {
      await initialize();
    }
    await _controller.start();
  }

  Future<void> stopScanning() async {
    if (_isInitialized) {
      await _controller.stop();
    }
  }

  Future<void> toggleTorch() async {
    if (_isInitialized) {
      await _controller.toggleTorch();
    }
  }

  Future<void> switchCamera() async {
    if (_isInitialized) {
      await _controller.switchCamera();
    }
  }

  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
      _isInitialized = false;
    }
  }

  // Validate barcode format
  bool isValidBarcode(String barcode, BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        return _isValidEAN13(barcode);
      case BarcodeFormat.ean8:
        return _isValidEAN8(barcode);
      case BarcodeFormat.upcA:
        return _isValidUPCA(barcode);
      case BarcodeFormat.upcE:
        return _isValidUPCE(barcode);
      case BarcodeFormat.code128:
        return _isValidCode128(barcode);
      case BarcodeFormat.code39:
        return _isValidCode39(barcode);
      case BarcodeFormat.qrCode:
        return barcode.isNotEmpty;
      default:
        return barcode.isNotEmpty;
    }
  }

  // EAN-13 validation
  bool _isValidEAN13(String barcode) {
    if (barcode.length != 13) return false;
    if (!RegExp(r'^\d+$').hasMatch(barcode)) return false;

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(barcode[12]);
  }

  // EAN-8 validation
  bool _isValidEAN8(String barcode) {
    if (barcode.length != 8) return false;
    if (!RegExp(r'^\d+$').hasMatch(barcode)) return false;

    int sum = 0;
    for (int i = 0; i < 7; i++) {
      int digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(barcode[7]);
  }

  // UPC-A validation
  bool _isValidUPCA(String barcode) {
    if (barcode.length != 12) return false;
    if (!RegExp(r'^\d+$').hasMatch(barcode)) return false;

    int sum = 0;
    for (int i = 0; i < 11; i++) {
      int digit = int.parse(barcode[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }

    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(barcode[11]);
  }

  // UPC-E validation
  bool _isValidUPCE(String barcode) {
    if (barcode.length != 8) return false;
    if (!RegExp(r'^\d+$').hasMatch(barcode)) return false;
    // UPC-E has complex validation rules, simplified check
    return true;
  }

  // Code 128 validation
  bool _isValidCode128(String barcode) {
    // Code 128 can contain alphanumeric characters
    return barcode.isNotEmpty && barcode.length >= 1;
  }

  // Code 39 validation
  bool _isValidCode39(String barcode) {
    // Code 39 supports uppercase letters, digits, and some special characters
    return RegExp(r'^[A-Z0-9\-\.\$\/\+\%\*\s]+$').hasMatch(barcode);
  }

  // Generate sample barcodes for testing
  static List<String> getSampleBarcodes() {
    return [
      '1234567890123', // Sample EAN-13
      '12345678',      // Sample EAN-8
      '123456789012',  // Sample UPC-A
      'SAMPLE123',     // Sample Code 39
      'https://example.com/product/123', // Sample QR Code
    ];
  }

  // Format barcode for display
  String formatBarcodeForDisplay(String barcode, BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        if (barcode.length == 13) {
          return '${barcode.substring(0, 1)} ${barcode.substring(1, 7)} ${barcode.substring(7, 13)}';
        }
        break;
      case BarcodeFormat.ean8:
        if (barcode.length == 8) {
          return '${barcode.substring(0, 4)} ${barcode.substring(4, 8)}';
        }
        break;
      case BarcodeFormat.upcA:
        if (barcode.length == 12) {
          return '${barcode.substring(0, 1)} ${barcode.substring(1, 6)} ${barcode.substring(6, 11)} ${barcode.substring(11, 12)}';
        }
        break;
      default:
        break;
    }
    return barcode;
  }

  // Get barcode format name
  String getBarcodeFormatName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      default:
        return 'Unknown';
    }
  }
}