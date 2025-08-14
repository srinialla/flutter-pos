import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/refund.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';
import '../models/receipt_config.dart';

class LocalStorageService {
  static const String _productsBox = 'products';
  static const String _salesBox = 'sales';
  static const String _settingsBox = 'settings';

  static LocalStorageService? _instance;
  static LocalStorageService get instance => _instance ??= LocalStorageService._();
  LocalStorageService._();

  late Box<Product> _products;
  late Box<Sale> _sales;
  late Box _settings;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // Register adapters for core models
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(SaleAdapter());
    Hive.registerAdapter(SaleItemAdapter());
    Hive.registerAdapter(PaymentMethodAdapter());
    
    // Register adapters for refund system
    Hive.registerAdapter(RefundAdapter());
    Hive.registerAdapter(RefundItemAdapter());
    Hive.registerAdapter(RefundAuditEntryAdapter());
    Hive.registerAdapter(RefundReasonAdapter());
    Hive.registerAdapter(RefundStatusAdapter());
    Hive.registerAdapter(RefundMethodAdapter());
    Hive.registerAdapter(RestockActionAdapter());
    
    // Register adapters for customer management
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(CustomerTypeAdapter());
    
    // Register adapters for supplier management
    Hive.registerAdapter(SupplierAdapter());
    Hive.registerAdapter(PaymentTermsAdapter());
    Hive.registerAdapter(SupplierStatusAdapter());
    
    // Register adapters for purchase orders
    Hive.registerAdapter(PurchaseOrderAdapter());
    Hive.registerAdapter(PurchaseOrderItemAdapter());
    Hive.registerAdapter(PurchaseOrderStatusAdapter());
    
    // Register adapters for receipt configuration
    Hive.registerAdapter(ReceiptConfigAdapter());
    Hive.registerAdapter(ReceiptTypeAdapter());
    Hive.registerAdapter(ReceiptSizeAdapter());
    Hive.registerAdapter(HeaderAlignmentAdapter());
    Hive.registerAdapter(PrinterConnectionAdapter());

    // Open boxes
    _products = await Hive.openBox<Product>(_productsBox);
    _sales = await Hive.openBox<Sale>(_salesBox);
    _settings = await Hive.openBox(_settingsBox);

    _isInitialized = true;
  }

  // Product operations
  Future<void> addProduct(Product product) async {
    await _products.put(product.id, product);
  }

  Future<void> updateProduct(Product product) async {
    await _products.put(product.id, product);
  }

  Future<void> saveProduct(Product product) async {
    await _products.put(product.id, product);
  }

  Future<void> deleteProduct(String productId) async {
    final product = _products.get(productId);
    if (product != null) {
      final updatedProduct = product.copyWith(isDeleted: true, isSynced: false);
      await _products.put(productId, updatedProduct);
    }
  }

  Product? getProduct(String productId) {
    return _products.get(productId);
  }

  List<Product> getAllProducts({bool includeDeleted = false}) {
    final products = _products.values.toList();
    if (includeDeleted) {
      return products;
    }
    return products.where((p) => !p.isDeleted).toList();
  }

  List<Product> searchProducts(String query) {
    final products = getAllProducts();
    return products.where((product) {
      final nameLower = product.name.toLowerCase();
      final queryLower = query.toLowerCase();
      final descriptionLower = product.description?.toLowerCase() ?? '';
      final barcode = product.barcode ?? '';
      
      return nameLower.contains(queryLower) ||
             descriptionLower.contains(queryLower) ||
             barcode.contains(query);
    }).toList();
  }

  Product? getProductByBarcode(String barcode) {
    final products = getAllProducts();
    try {
      return products.firstWhere((product) => product.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  List<Product> getUnsyncedProducts() {
    return _products.values.where((p) => !p.isSynced).toList();
  }

  // Sale operations
  Future<void> addSale(Sale sale) async {
    await _sales.put(sale.id, sale);
  }

  Future<void> updateSale(Sale sale) async {
    await _sales.put(sale.id, sale);
  }

  Sale? getSale(String saleId) {
    return _sales.get(saleId);
  }

  List<Sale> getAllSales() {
    return _sales.values.toList();
  }

  List<Sale> getSalesByDateRange(DateTime start, DateTime end) {
    final sales = getAllSales();
    return sales.where((sale) {
      return sale.createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
             sale.createdAt.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<Sale> getTodaySales() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  List<Sale> getUnsyncedSales() {
    return _sales.values.where((s) => !s.isSynced).toList();
  }

  // Settings operations
  Future<void> setSetting(String key, dynamic value) async {
    await _settings.put(key, value);
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings.get(key, defaultValue: defaultValue) as T?;
  }

  // Statistics
  double getTodaysTotal() {
    final todaySales = getTodaySales();
    return todaySales.fold(0.0, (sum, sale) => sum + sale.total);
  }

  int getTodaysSalesCount() {
    return getTodaySales().length;
  }

  Map<String, int> getTopSellingProducts(int limit) {
    final sales = getAllSales();
    final productCounts = <String, int>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        productCounts[item.productName] = 
            (productCounts[item.productName] ?? 0) + item.quantity;
      }
    }

    final sorted = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted.take(limit));
  }

  // Low stock products
  List<Product> getLowStockProducts({int threshold = 10}) {
    final products = getAllProducts();
    return products.where((p) => p.stockQuantity <= threshold).toList();
  }

  // Sync helpers
  Future<void> markProductAsSynced(String productId) async {
    final product = _products.get(productId);
    if (product != null) {
      final synced = product.copyWith(isSynced: true);
      await _products.put(productId, synced);
    }
  }

  Future<void> markSaleAsSynced(String saleId) async {
    final sale = _sales.get(saleId);
    if (sale != null) {
      sale.isSynced = true;
      await sale.save();
    }
  }

  // Clear data
  Future<void> clearAllData() async {
    await _products.clear();
    await _sales.clear();
    await _settings.clear();
  }

  // Generic box access for services
  Future<Box<T>> getBox<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    return await Hive.openBox<T>(boxName);
  }

  // Close boxes
  Future<void> close() async {
    await _products.close();
    await _sales.close();
    await _settings.close();
    _isInitialized = false;
  }
}