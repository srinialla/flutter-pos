import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';
import '../utils/platform_utils.dart';
import 'local_storage_service.dart';
import 'analytics_service.dart';

class ExportService {
  static ExportService? _instance;
  static ExportService get instance => _instance ??= ExportService._();
  ExportService._();

  final LocalStorageService _localStorage = LocalStorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  // Export Products
  Future<ExportResult> exportProducts({
    ExportFormat format = ExportFormat.csv,
    DateRange? dateRange,
    List<String>? categories,
    bool includeDeleted = false,
    String? customPath,
  }) async {
    try {
      final products = _localStorage.getAllProducts(includeDeleted: includeDeleted);
      
      // Filter by date range
      List<Product> filteredProducts = products;
      if (dateRange != null) {
        filteredProducts = products.where((product) =>
            product.createdAt.isAfter(dateRange.start) &&
            product.createdAt.isBefore(dateRange.end)).toList();
      }
      
      // Filter by categories
      if (categories != null && categories.isNotEmpty) {
        filteredProducts = filteredProducts.where((product) =>
            categories.contains(product.category)).toList();
      }

      switch (format) {
        case ExportFormat.csv:
          return await _exportProductsCSV(filteredProducts, customPath);
        case ExportFormat.excel:
          return await _exportProductsExcel(filteredProducts, customPath);
        case ExportFormat.pdf:
          return await _exportProductsPDF(filteredProducts, customPath);
        case ExportFormat.json:
          return await _exportProductsJSON(filteredProducts, customPath);
      }
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'product_export_failed');
      return ExportResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  Future<ExportResult> _exportProductsCSV(List<Product> products, String? customPath) async {
    try {
      final csvData = [
        [
          'ID',
          'Name',
          'Description',
          'Barcode',
          'Price',
          'Cost',
          'Category',
          'Stock Quantity',
          'Created At',
          'Updated At',
        ],
        ...products.map((product) => [
          product.id,
          product.name,
          product.description ?? '',
          product.barcode ?? '',
          product.price.toString(),
          product.cost?.toString() ?? '',
          product.category,
          product.stockQuantity.toString(),
          product.createdAt.toIso8601String(),
          product.updatedAt.toIso8601String(),
        ]),
      ];

      final csv = const ListToCsvConverter().convert(csvData);
      final fileName = 'products_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final file = await _saveFile(csv, fileName, customPath);
      
      await _analytics.trackEvent('data_exported', {
        'type': 'products',
        'format': 'csv',
        'count': products.length,
      });

      return ExportResult(
        success: true,
        message: 'Products exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: products.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'CSV export failed: $e',
      );
    }
  }

  Future<ExportResult> _exportProductsExcel(List<Product> products, String? customPath) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Products'];

      // Headers
      final headers = [
        'ID', 'Name', 'Description', 'Barcode', 'Price', 'Cost',
        'Category', 'Stock Quantity', 'Created At', 'Updated At'
      ];
      
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i];
        cell.cellStyle = CellStyle(bold: true);
      }

      // Data rows
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final row = [
          product.id,
          product.name,
          product.description ?? '',
          product.barcode ?? '',
          product.price,
          product.cost ?? 0.0,
          product.category,
          product.stockQuantity,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(product.createdAt),
          DateFormat('yyyy-MM-dd HH:mm:ss').format(product.updatedAt),
        ];
        
        for (int j = 0; j < row.length; j++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.value = row[j];
        }
      }

      final bytes = excel.save();
      final fileName = 'products_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final file = await _saveFileBytes(Uint8List.fromList(bytes!), fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'products',
        'format': 'excel',
        'count': products.length,
      });

      return ExportResult(
        success: true,
        message: 'Products exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: products.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Excel export failed: $e',
      );
    }
  }

  Future<ExportResult> _exportProductsPDF(List<Product> products, String? customPath) async {
    try {
      final pdf = pw.Document();

      // Split products into pages
      const itemsPerPage = 30;
      final pageCount = (products.length / itemsPerPage).ceil();

      for (int page = 0; page < pageCount; page++) {
        final startIndex = page * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, products.length);
        final pageProducts = products.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Text('Products Export - Page ${page + 1}'),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    headers: ['Name', 'Category', 'Price', 'Stock', 'Barcode'],
                    data: pageProducts.map((product) => [
                      product.name,
                      product.category,
                      '\$${product.price.toStringAsFixed(2)}',
                      product.stockQuantity.toString(),
                      product.barcode ?? 'N/A',
                    ]).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      final fileName = 'products_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final file = await _saveFileBytes(bytes, fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'products',
        'format': 'pdf',
        'count': products.length,
      });

      return ExportResult(
        success: true,
        message: 'Products exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: products.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'PDF export failed: $e',
      );
    }
  }

  Future<ExportResult> _exportProductsJSON(List<Product> products, String? customPath) async {
    try {
      final jsonData = {
        'exported_at': DateTime.now().toIso8601String(),
        'total_count': products.length,
        'products': products.map((product) => product.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final fileName = 'products_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      final file = await _saveFile(jsonString, fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'products',
        'format': 'json',
        'count': products.length,
      });

      return ExportResult(
        success: true,
        message: 'Products exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: products.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'JSON export failed: $e',
      );
    }
  }

  // Export Sales
  Future<ExportResult> exportSales({
    ExportFormat format = ExportFormat.csv,
    DateRange? dateRange,
    List<PaymentMethod>? paymentMethods,
    String? customPath,
  }) async {
    try {
      List<Sale> sales = _localStorage.getAllSales();
      
      // Filter by date range
      if (dateRange != null) {
        sales = sales.where((sale) =>
            sale.createdAt.isAfter(dateRange.start) &&
            sale.createdAt.isBefore(dateRange.end)).toList();
      }
      
      // Filter by payment methods
      if (paymentMethods != null && paymentMethods.isNotEmpty) {
        sales = sales.where((sale) =>
            paymentMethods.contains(sale.paymentMethod)).toList();
      }

      switch (format) {
        case ExportFormat.csv:
          return await _exportSalesCSV(sales, customPath);
        case ExportFormat.excel:
          return await _exportSalesExcel(sales, customPath);
        case ExportFormat.pdf:
          return await _exportSalesPDF(sales, customPath);
        case ExportFormat.json:
          return await _exportSalesJSON(sales, customPath);
      }
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'sales_export_failed');
      return ExportResult(
        success: false,
        message: 'Export failed: $e',
      );
    }
  }

  Future<ExportResult> _exportSalesCSV(List<Sale> sales, String? customPath) async {
    try {
      final csvData = [
        [
          'Sale ID',
          'Date',
          'Items Count',
          'Subtotal',
          'Tax Rate',
          'Tax Amount',
          'Discount',
          'Total',
          'Payment Method',
          'Amount Paid',
          'Change',
          'Customer ID',
          'Notes',
        ],
        ...sales.map((sale) => [
          sale.id,
          sale.createdAt.toIso8601String(),
          sale.items.length.toString(),
          sale.subtotal.toString(),
          '${(sale.taxRate * 100).toStringAsFixed(1)}%',
          sale.taxAmount.toString(),
          sale.discount.toString(),
          sale.total.toString(),
          sale.paymentMethod.toString().split('.').last,
          sale.amountPaid.toString(),
          sale.change.toString(),
          sale.customerId ?? '',
          sale.notes ?? '',
        ]),
      ];

      final csv = const ListToCsvConverter().convert(csvData);
      final fileName = 'sales_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final file = await _saveFile(csv, fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'sales',
        'format': 'csv',
        'count': sales.length,
        'total_amount': sales.fold<double>(0, (sum, sale) => sum + sale.total),
      });

      return ExportResult(
        success: true,
        message: 'Sales exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: sales.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'CSV export failed: $e',
      );
    }
  }

  Future<ExportResult> _exportSalesExcel(List<Sale> sales, String? customPath) async {
    try {
      final excel = Excel.createExcel();
      
      // Sales Summary Sheet
      final summarySheet = excel['Sales Summary'];
      _createSalesSummarySheet(summarySheet, sales);
      
      // Detailed Sales Sheet
      final detailSheet = excel['Sales Details'];
      _createSalesDetailSheet(detailSheet, sales);

      final bytes = excel.save();
      final fileName = 'sales_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final file = await _saveFileBytes(Uint8List.fromList(bytes!), fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'sales',
        'format': 'excel',
        'count': sales.length,
        'total_amount': sales.fold<double>(0, (sum, sale) => sum + sale.total),
      });

      return ExportResult(
        success: true,
        message: 'Sales exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: sales.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'Excel export failed: $e',
      );
    }
  }

  void _createSalesSummarySheet(Sheet sheet, List<Sale> sales) {
    // Headers
    final headers = ['Date', 'Sales Count', 'Total Revenue', 'Avg Sale Amount'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(bold: true);
    }

    // Group sales by date
    final dailySales = <String, List<Sale>>{};
    for (final sale in sales) {
      final dateKey = DateFormat('yyyy-MM-dd').format(sale.createdAt);
      dailySales[dateKey] = (dailySales[dateKey] ?? [])..add(sale);
    }

    // Add daily summary data
    int rowIndex = 1;
    for (final entry in dailySales.entries) {
      final date = entry.key;
      final daySales = entry.value;
      final totalRevenue = daySales.fold<double>(0, (sum, sale) => sum + sale.total);
      final avgSaleAmount = totalRevenue / daySales.length;

      final row = [
        date,
        daySales.length,
        totalRevenue,
        avgSaleAmount,
      ];

      for (int j = 0; j < row.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
        cell.value = row[j];
      }
      rowIndex++;
    }
  }

  void _createSalesDetailSheet(Sheet sheet, List<Sale> sales) {
    // Headers
    final headers = [
      'Sale ID', 'Date', 'Items', 'Subtotal', 'Tax', 'Discount',
      'Total', 'Payment Method', 'Amount Paid', 'Change'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = headers[i];
      cell.cellStyle = CellStyle(bold: true);
    }

    // Data rows
    for (int i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final row = [
        sale.id.substring(0, 8),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(sale.createdAt),
        sale.items.length,
        sale.subtotal,
        sale.taxAmount,
        sale.discount,
        sale.total,
        sale.paymentMethod.toString().split('.').last,
        sale.amountPaid,
        sale.change,
      ];
      
      for (int j = 0; j < row.length; j++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
        cell.value = row[j];
      }
    }
  }

  Future<ExportResult> _exportSalesPDF(List<Sale> sales, String? customPath) async {
    try {
      final pdf = pw.Document();

      // Sales Summary Page
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => _buildSalesSummaryPage(sales),
        ),
      );

      // Detailed Sales Pages
      const itemsPerPage = 20;
      final pageCount = (sales.length / itemsPerPage).ceil();

      for (int page = 0; page < pageCount; page++) {
        final startIndex = page * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, sales.length);
        final pageSales = sales.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) => _buildSalesDetailPage(pageSales, page + 1),
          ),
        );
      }

      final bytes = await pdf.save();
      final fileName = 'sales_export_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final file = await _saveFileBytes(bytes, fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'sales',
        'format': 'pdf',
        'count': sales.length,
        'total_amount': sales.fold<double>(0, (sum, sale) => sum + sale.total),
      });

      return ExportResult(
        success: true,
        message: 'Sales exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: sales.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'PDF export failed: $e',
      );
    }
  }

  pw.Widget _buildSalesSummaryPage(List<Sale> sales) {
    final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final avgSaleAmount = sales.isNotEmpty ? totalRevenue / sales.length : 0;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 0, child: pw.Text('Sales Summary')),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryCard('Total Sales', sales.length.toString()),
            _buildSummaryCard('Total Revenue', '\$${totalRevenue.toStringAsFixed(2)}'),
            _buildSummaryCard('Average Sale', '\$${avgSaleAmount.toStringAsFixed(2)}'),
          ],
        ),
        pw.SizedBox(height: 30),
        pw.Text('Export Period: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
      ],
    );
  }

  pw.Widget _buildSummaryCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(value, style: const pw.TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  pw.Widget _buildSalesDetailPage(List<Sale> sales, int pageNumber) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 0,
          child: pw.Text('Sales Details - Page $pageNumber'),
        ),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: ['Date', 'Sale ID', 'Items', 'Total', 'Payment'],
          data: sales.map((sale) => [
            DateFormat('MM/dd HH:mm').format(sale.createdAt),
            sale.id.substring(0, 8),
            sale.items.length.toString(),
            '\$${sale.total.toStringAsFixed(2)}',
            sale.paymentMethod.toString().split('.').last,
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  Future<ExportResult> _exportSalesJSON(List<Sale> sales, String? customPath) async {
    try {
      final jsonData = {
        'exported_at': DateTime.now().toIso8601String(),
        'total_count': sales.length,
        'total_revenue': sales.fold<double>(0, (sum, sale) => sum + sale.total),
        'sales': sales.map((sale) => sale.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final fileName = 'sales_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      final file = await _saveFile(jsonString, fileName, customPath);

      await _analytics.trackEvent('data_exported', {
        'type': 'sales',
        'format': 'json',
        'count': sales.length,
        'total_amount': sales.fold<double>(0, (sum, sale) => sum + sale.total),
      });

      return ExportResult(
        success: true,
        message: 'Sales exported successfully',
        filePath: file.path,
        fileName: fileName,
        recordCount: sales.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: 'JSON export failed: $e',
      );
    }
  }

  // File Management
  Future<File> _saveFile(String content, String fileName, String? customPath) async {
    final directory = customPath != null 
        ? Directory(customPath)
        : await _getExportDirectory();
    
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  Future<File> _saveFileBytes(Uint8List bytes, String fileName, String? customPath) async {
    final directory = customPath != null 
        ? Directory(customPath)
        : await _getExportDirectory();
    
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Directory> _getExportDirectory() async {
    if (PlatformUtils.isWeb) {
      // For web, use Downloads folder
      return Directory('/Downloads');
    } else if (PlatformUtils.isDesktop) {
      final documentsDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${documentsDir.path}/POS_Exports');
      
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      return exportDir;
    } else {
      // Mobile - use app documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  // Share exported files
  Future<void> shareExportedFile(String filePath) async {
    try {
      if (PlatformUtils.isMobile) {
        await Share.shareXFiles([XFile(filePath)]);
      } else {
        await OpenFile.open(filePath);
      }
      
      await _analytics.trackEvent('export_shared', {
        'file_path': filePath,
        'platform': PlatformUtils.getPlatformName(),
      });
    } catch (e) {
      await _analytics.recordError(e, StackTrace.current, 'export_share_failed');
    }
  }

  // Get available export locations
  Future<List<String>> getAvailableExportLocations() async {
    final locations = <String>[];
    
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      locations.add(documentsDir.path);
      
      if (PlatformUtils.isAndroid) {
        locations.add('/storage/emulated/0/Download');
        locations.add('/storage/emulated/0/Documents');
      }
      
      // Allow custom path selection
      locations.add('Custom Location...');
    } catch (e) {
      debugPrint('Failed to get export locations: $e');
    }
    
    return locations;
  }

  Future<String?> selectCustomExportPath() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      debugPrint('Failed to select custom path: $e');
      return null;
    }
  }
}

enum ExportFormat {
  csv,
  excel,
  pdf,
  json,
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({
    required this.start,
    required this.end,
  });
}

class ExportResult {
  final bool success;
  final String message;
  final String? filePath;
  final String? fileName;
  final int recordCount;

  ExportResult({
    required this.success,
    required this.message,
    this.filePath,
    this.fileName,
    this.recordCount = 0,
  });
}

extension ExportFormatExtension on ExportFormat {
  String get displayName {
    switch (this) {
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.excel:
        return 'Excel';
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.json:
        return 'JSON';
    }
  }

  String get fileExtension {
    switch (this) {
      case ExportFormat.csv:
        return '.csv';
      case ExportFormat.excel:
        return '.xlsx';
      case ExportFormat.pdf:
        return '.pdf';
      case ExportFormat.json:
        return '.json';
    }
  }
}