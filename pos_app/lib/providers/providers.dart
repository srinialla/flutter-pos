import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../repositories/product_repository.dart';
import '../repositories/sales_repository.dart';

final hiveInitProvider = FutureProvider<void>((ref) async {
  await HiveService.init();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.create();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    productRepository: ref.read(productRepositoryProvider),
    salesRepository: ref.read(salesRepositoryProvider),
  );
});