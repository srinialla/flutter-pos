import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/inventory_change.dart';
import '../services/hive_service.dart';

class SalesRepository {
  final Box<Sale> _salesBox;
  final Box<Product> _productsBox;
  final Box<InventoryChange> _invBox;
  final Uuid _uuid;

  SalesRepository({
    Box<Sale>? salesBox,
    Box<Product>? productsBox,
    Box<InventoryChange>? invBox,
    Uuid? uuid,
  })  : _salesBox = salesBox ?? HiveService.salesBox,
        _productsBox = productsBox ?? HiveService.productsBox,
        _invBox = invBox ?? HiveService.inventoryChangesBox,
        _uuid = uuid ?? const Uuid();

  Iterable<Sale> getAll() => _salesBox.values;

  Future<Sale> createSale({
    required List<SaleItem> items,
    double orderDiscount = 0.0,
    required double taxRatePercent,
    double cashPaid = 0.0,
    double cardPaid = 0.0,
    double mobileMoneyPaid = 0.0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final sale = Sale(
      id: id,
      items: items,
      discount: orderDiscount,
      taxRatePercent: taxRatePercent,
      cashPaid: cashPaid,
      cardPaid: cardPaid,
      mobileMoneyPaid: mobileMoneyPaid,
      createdAt: now,
      updatedAt: now,
    );
    await _salesBox.put(id, sale);

    // Deduct stock and log inventory changes
    for (final item in items) {
      final product = _productsBox.get(item.productId);
      if (product == null) continue;
      final updated = product.copyWith(
        stockQuantity: product.stockQuantity - item.quantity,
        updatedAt: now,
      );
      await _productsBox.put(updated.id, updated);
      final change = InventoryChange(
        id: _uuid.v4(),
        productId: product.id,
        delta: -item.quantity,
        reason: 'sale',
        createdAt: now,
      );
      await _invBox.put(change.id, change);
    }

    return sale;
  }

  Future<void> recordManualAdjustment({
    required String productId,
    required int delta,
    required String reason,
  }) async {
    final product = _productsBox.get(productId);
    if (product == null) return;
    final now = DateTime.now().toUtc();
    final updated = product.copyWith(
      stockQuantity: product.stockQuantity + delta,
      updatedAt: now,
    );
    await _productsBox.put(updated.id, updated);
    final change = InventoryChange(
      id: _uuid.v4(),
      productId: productId,
      delta: delta,
      reason: reason,
      createdAt: now,
    );
    await _invBox.put(change.id, change);
  }
}