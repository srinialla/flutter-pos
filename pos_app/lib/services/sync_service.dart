import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../core/config.dart';
import '../models/product.dart';

import '../repositories/product_repository.dart';
import '../repositories/sales_repository.dart';

class SyncService {
  final ProductRepository _productRepo;
  final SalesRepository _salesRepo;
  final fs.FirebaseFirestore? _firestore;

  SyncService({required ProductRepository productRepository, required SalesRepository salesRepository})
      : _productRepo = productRepository,
        _salesRepo = salesRepository,
        _firestore = AppConfig.useFirebase ? fs.FirebaseFirestore.instance : null;

  Future<void> syncAll() async {
    if (_firestore == null) return;
    await Future.wait([
      _syncProducts(),
      _syncSales(),
      _syncInventoryChanges(),
    ]);
  }

  Future<void> _syncProducts() async {
    if (_firestore == null) return;
    final col = _firestore!.collection('products');

    // Upload local products
    for (final p in _productRepo.getAll()) {
      await col.doc(p.id).set(p.toJson(), fs.SetOptions(merge: true));
    }

    // Download remote updates
    final snap = await col.get();
    for (final doc in snap.docs) {
      final data = doc.data();
      try {
        final remote = Product.fromJson(data);
        await _productRepo.upsertFromRemote(remote);
      } catch (_) {
        // ignore malformed
      }
    }
  }

  Future<void> _syncSales() async {
    if (_firestore == null) return;
    final col = _firestore!.collection('sales');
    for (final s in _salesRepo.getAll()) {
      await col.doc(s.id).set(s.toJson(), fs.SetOptions(merge: true));
    }
  }

  Future<void> _syncInventoryChanges() async {
    if (_firestore == null) return;
    final _ = _firestore!.collection('inventory_changes');
    // One-way upload for v1; remote is for aggregation/reporting.
    // In v2, we could download too if needed.
  }
}