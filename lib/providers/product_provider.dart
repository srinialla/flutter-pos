import 'package:flutter/foundation.dart';

import '../core/models/product.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/sync_service.dart';

class ProductProvider extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SyncService _syncService = SyncService.instance;

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<Product> get products => _filteredProducts;
  List<Product> get allProducts => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  ProductProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    _setLoading(true);
    _clearError();

    try {
      _products = _localStorage.getAllProducts();
      _applyFilters();
    } catch (e) {
      _setError('Failed to load products: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addProduct(Product product) async {
    _setLoading(true);
    _clearError();

    try {
      await _localStorage.addProduct(product);
      
      // Try to sync immediately if online
      _syncService.uploadProduct(product);
      
      await loadProducts();
      return true;
    } catch (e) {
      _setError('Failed to add product: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProduct(Product product) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedProduct = product.copyWith(isSynced: false);
      await _localStorage.updateProduct(updatedProduct);
      
      // Try to sync immediately if online
      _syncService.uploadProduct(updatedProduct);
      
      await loadProducts();
      return true;
    } catch (e) {
      _setError('Failed to update product: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _setLoading(true);
    _clearError();

    try {
      await _localStorage.deleteProduct(productId);
      
      // Try to sync deletion immediately if online
      final deletedProduct = _localStorage.getProduct(productId);
      if (deletedProduct != null) {
        _syncService.uploadProduct(deletedProduct);
      }
      
      await loadProducts();
      return true;
    } catch (e) {
      _setError('Failed to delete product: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Product? getProduct(String productId) {
    return _localStorage.getProduct(productId);
  }

  Product? getProductByBarcode(String barcode) {
    return _localStorage.getProductByBarcode(barcode);
  }

  Future<void> updateStock(String productId, int newQuantity) async {
    final product = getProduct(productId);
    if (product != null) {
      final updatedProduct = product.copyWith(
        stockQuantity: newQuantity,
        isSynced: false,
      );
      await updateProduct(updatedProduct);
    }
  }

  Future<void> adjustStock(String productId, int adjustment, {String? reason}) async {
    final product = getProduct(productId);
    if (product != null) {
      final newQuantity = product.stockQuantity + adjustment;
      if (newQuantity >= 0) {
        await updateStock(productId, newQuantity);
      }
    }
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void filterByCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredProducts = _products;

    // Apply category filter
    if (_selectedCategory != 'All') {
      _filteredProducts = _filteredProducts
          .where((product) => product.category == _selectedCategory)
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      _filteredProducts = _filteredProducts.where((product) {
        final nameLower = product.name.toLowerCase();
        final queryLower = _searchQuery.toLowerCase();
        final descriptionLower = product.description?.toLowerCase() ?? '';
        final barcode = product.barcode ?? '';
        
        return nameLower.contains(queryLower) ||
               descriptionLower.contains(queryLower) ||
               barcode.contains(_searchQuery);
      }).toList();
    }

    // Sort by name
    _filteredProducts.sort((a, b) => a.name.compareTo(b.name));
  }

  void clearSearch() {
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _applyFilters();
    notifyListeners();
  }

  List<String> getCategories() {
    final categories = _products.map((p) => p.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<Product> getLowStockProducts({int threshold = 10}) {
    return _localStorage.getLowStockProducts(threshold: threshold);
  }

  int get totalProducts => _products.length;
  int get lowStockCount => getLowStockProducts().length;

  double get totalInventoryValue {
    return _products.fold(0.0, (sum, product) {
      final cost = product.cost ?? product.price;
      return sum + (cost * product.stockQuantity);
    });
  }

  // Statistics
  Map<String, int> getCategoryDistribution() {
    final distribution = <String, int>{};
    for (final product in _products) {
      distribution[product.category] = (distribution[product.category] ?? 0) + 1;
    }
    return distribution;
  }

  List<Product> getTopSellingProducts(int limit) {
    // This would need sales data to implement properly
    // For now, return products sorted by stock (assuming low stock = high sales)
    final sorted = List<Product>.from(_products);
    sorted.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    return sorted.take(limit).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() => _clearError();

  // Bulk operations
  Future<bool> importProducts(List<Product> products) async {
    _setLoading(true);
    _clearError();

    try {
      for (final product in products) {
        await _localStorage.addProduct(product);
      }
      
      await loadProducts();
      return true;
    } catch (e) {
      _setError('Failed to import products: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  List<Product> exportProducts() {
    return List<Product>.from(_products);
  }

  // Generate sample products for testing
  Future<void> generateSampleProducts() async {
    final sampleProducts = [
      Product(
        name: 'Coca Cola 330ml',
        price: 1.50,
        cost: 1.00,
        category: 'Beverages',
        stockQuantity: 50,
        barcode: '1234567890123',
        description: 'Refreshing cola drink',
      ),
      Product(
        name: 'White Bread',
        price: 2.00,
        cost: 1.50,
        category: 'Bakery',
        stockQuantity: 20,
        barcode: '2345678901234',
        description: 'Fresh white bread loaf',
      ),
      Product(
        name: 'Milk 1L',
        price: 3.50,
        cost: 2.50,
        category: 'Dairy',
        stockQuantity: 30,
        barcode: '3456789012345',
        description: 'Fresh whole milk',
      ),
      Product(
        name: 'Bananas 1kg',
        price: 2.50,
        cost: 1.80,
        category: 'Fruits',
        stockQuantity: 25,
        barcode: '4567890123456',
        description: 'Fresh ripe bananas',
      ),
      Product(
        name: 'Chicken Breast 500g',
        price: 8.00,
        cost: 6.00,
        category: 'Meat',
        stockQuantity: 15,
        barcode: '5678901234567',
        description: 'Fresh chicken breast',
      ),
    ];

    for (final product in sampleProducts) {
      await addProduct(product);
    }
  }
}