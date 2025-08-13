import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../services/hive_service.dart';

class ProductRepository {
  final Box<Product> _box;
  final Uuid _uuid;

  ProductRepository({Box<Product>? box, Uuid? uuid})
      : _box = box ?? HiveService.productsBox,
        _uuid = uuid ?? const Uuid();

  Iterable<Product> getAll() => _box.values;

  Product? getById(String id) => _box.get(id);

  Product? getByBarcode(String barcode) => _box.values.firstWhereOrNull((p) => p.barcode == barcode);

  Iterable<Product> searchByNameOrBarcode(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return _box.values;
    return _box.values.where((p) =>
        (p.name.toLowerCase().contains(q)) || (p.barcode?.toLowerCase().contains(q) ?? false));
  }

  Future<Product> create({
    String? id,
    required String name,
    String? description,
    String? barcode,
    required double price,
    double? cost,
    String? category,
    required int stockQuantity,
    String? imageBase64,
  }) async {
    final now = DateTime.now().toUtc();
    final product = Product(
      id: id ?? _uuid.v4(),
      name: name,
      description: description,
      barcode: barcode,
      price: price,
      cost: cost,
      category: category,
      stockQuantity: stockQuantity,
      imageBase64: imageBase64,
      updatedAt: now,
    );
    await _box.put(product.id, product);
    return product;
  }

  Future<Product> update(Product product) async {
    final updated = product.copyWith(updatedAt: DateTime.now().toUtc());
    await _box.put(updated.id, updated);
    return updated;
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> upsertFromRemote(Product remote) async {
    // assumes remote.updatedAt has been parsed and is authoritative
    final local = _box.get(remote.id);
    if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
      await _box.put(remote.id, remote);
    }
  }
}