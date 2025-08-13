import 'package:flutter/foundation.dart';

import '../core/models/product.dart';
import '../core/models/sale.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/sync_service.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0.0,
  });

  double get total => (product.price * quantity) - discount;
  double get subtotal => product.price * quantity;
}

class SalesProvider extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SyncService _syncService = SyncService.instance;

  List<CartItem> _cartItems = [];
  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _errorMessage;
  double _taxRate = 0.1; // 10% default tax
  double _orderDiscount = 0.0;

  List<CartItem> get cartItems => _cartItems;
  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get taxRate => _taxRate;
  double get orderDiscount => _orderDiscount;

  SalesProvider() {
    loadSales();
    _loadSettings();
  }

  void _loadSettings() {
    _taxRate = _localStorage.getSetting<double>('taxRate', defaultValue: 0.1) ?? 0.1;
  }

  Future<void> loadSales() async {
    _setLoading(true);
    _clearError();

    try {
      _sales = _localStorage.getAllSales();
      _sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _setError('Failed to load sales: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Cart management
  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += quantity;
    } else {
      _cartItems.add(CartItem(product: product, quantity: quantity));
    }
    
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateCartItemQuantity(String productId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void updateCartItemDiscount(String productId, double discount) {
    final index = _cartItems.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _cartItems[index].discount = discount;
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    _orderDiscount = 0.0;
    notifyListeners();
  }

  void setOrderDiscount(double discount) {
    _orderDiscount = discount;
    notifyListeners();
  }

  void setTaxRate(double rate) {
    _taxRate = rate;
    _localStorage.setSetting('taxRate', rate);
    notifyListeners();
  }

  // Cart calculations
  double get cartSubtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get cartItemsDiscount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.discount);
  }

  double get cartTotal {
    final subtotal = cartSubtotal - cartItemsDiscount - _orderDiscount;
    final tax = subtotal * _taxRate;
    return subtotal + tax;
  }

  double get cartTaxAmount {
    final subtotal = cartSubtotal - cartItemsDiscount - _orderDiscount;
    return subtotal * _taxRate;
  }

  int get cartItemCount {
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  bool get isCartEmpty => _cartItems.isEmpty;

  // Checkout
  Future<Sale?> checkout({
    required PaymentMethod paymentMethod,
    required double amountPaid,
    String? notes,
  }) async {
    if (_cartItems.isEmpty) {
      _setError('Cart is empty');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final saleItems = _cartItems.map((cartItem) => SaleItem(
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        unitPrice: cartItem.product.price,
        quantity: cartItem.quantity,
        discount: cartItem.discount,
        total: cartItem.total,
      )).toList();

      final subtotal = cartSubtotal;
      final totalDiscount = cartItemsDiscount + _orderDiscount;
      final taxAmount = cartTaxAmount;
      final total = cartTotal;
      final change = amountPaid - total;

      final sale = Sale(
        items: saleItems,
        subtotal: subtotal,
        taxRate: _taxRate,
        taxAmount: taxAmount,
        discount: totalDiscount,
        total: total,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        change: change > 0 ? change : 0.0,
        notes: notes,
      );

      // Save sale locally
      await _localStorage.addSale(sale);

      // Update product stock
      for (final cartItem in _cartItems) {
        final product = cartItem.product;
        final newStock = product.stockQuantity - cartItem.quantity;
        if (newStock >= 0) {
          final updatedProduct = product.copyWith(
            stockQuantity: newStock,
            isSynced: false,
          );
          await _localStorage.updateProduct(updatedProduct);
        }
      }

      // Try to sync immediately if online
      _syncService.uploadSale(sale);

      // Clear cart
      clearCart();

      // Reload sales
      await loadSales();

      return sale;
    } catch (e) {
      _setError('Checkout failed: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Sales queries
  List<Sale> getTodaySales() {
    return _localStorage.getTodaySales();
  }

  List<Sale> getSalesByDateRange(DateTime start, DateTime end) {
    return _localStorage.getSalesByDateRange(start, end);
  }

  Sale? getSale(String saleId) {
    return _localStorage.getSale(saleId);
  }

  // Sales statistics
  double getTodaysTotal() {
    return _localStorage.getTodaysTotal();
  }

  int getTodaysSalesCount() {
    return _localStorage.getTodaysSalesCount();
  }

  double getTotalSales() {
    return _sales.fold(0.0, (sum, sale) => sum + sale.total);
  }

  Map<String, double> getDailySales(int days) {
    final now = DateTime.now();
    final salesMap = <String, double>{};

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final dailySales = getSalesByDateRange(startOfDay, endOfDay);
      final total = dailySales.fold(0.0, (sum, sale) => sum + sale.total);
      
      salesMap[dateKey] = total;
    }

    return salesMap;
  }

  Map<PaymentMethod, double> getPaymentMethodBreakdown() {
    final breakdown = <PaymentMethod, double>{};
    
    for (final sale in _sales) {
      breakdown[sale.paymentMethod] = 
          (breakdown[sale.paymentMethod] ?? 0.0) + sale.total;
    }
    
    return breakdown;
  }

  Map<String, int> getTopSellingProducts(int limit) {
    return _localStorage.getTopSellingProducts(limit);
  }

  // Receipt generation
  String generateReceiptText(Sale sale) {
    final buffer = StringBuffer();
    
    buffer.writeln('=================================');
    buffer.writeln('           RECEIPT              ');
    buffer.writeln('=================================');
    buffer.writeln('Date: ${sale.createdAt.toString().substring(0, 19)}');
    buffer.writeln('Sale ID: ${sale.id.substring(0, 8)}');
    buffer.writeln('---------------------------------');
    
    for (final item in sale.items) {
      buffer.writeln('${item.productName}');
      buffer.writeln('  ${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)} = \$${item.total.toStringAsFixed(2)}');
      if (item.discount > 0) {
        buffer.writeln('  Discount: -\$${item.discount.toStringAsFixed(2)}');
      }
    }
    
    buffer.writeln('---------------------------------');
    buffer.writeln('Subtotal: \$${sale.subtotal.toStringAsFixed(2)}');
    if (sale.discount > 0) {
      buffer.writeln('Discount: -\$${sale.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('Tax (${(sale.taxRate * 100).toStringAsFixed(1)}%): \$${sale.taxAmount.toStringAsFixed(2)}');
    buffer.writeln('=================================');
    buffer.writeln('TOTAL: \$${sale.total.toStringAsFixed(2)}');
    buffer.writeln('=================================');
    buffer.writeln('Payment: ${sale.paymentMethod.toString().split('.').last.toUpperCase()}');
    buffer.writeln('Amount Paid: \$${sale.amountPaid.toStringAsFixed(2)}');
    if (sale.change > 0) {
      buffer.writeln('Change: \$${sale.change.toStringAsFixed(2)}');
    }
    buffer.writeln('=================================');
    buffer.writeln('Thank you for your business!');
    
    return buffer.toString();
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
}