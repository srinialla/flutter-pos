import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/inventory_change.dart';

class HiveService {
  static const String productsBoxName = 'products_box';
  static const String salesBoxName = 'sales_box';
  static const String inventoryChangesBoxName = 'inventory_changes_box';
  static const String settingsBoxName = 'settings_box';

  static Future<void> init() async {
    // For mobile/desktop, normal init. For web, Hive.initFlutter handles it.
    await Hive.initFlutter();

    // Register adapters
    Hive
      ..registerAdapter(ProductAdapter())
      ..registerAdapter(SaleItemAdapter())
      ..registerAdapter(SaleAdapter())
      ..registerAdapter(InventoryChangeAdapter());

    // Open boxes
    await Future.wait([
      Hive.openBox<Product>(productsBoxName),
      Hive.openBox<Sale>(salesBoxName),
      Hive.openBox<InventoryChange>(inventoryChangesBoxName),
      Hive.openBox(settingsBoxName),
    ]);
  }

  static Box<Product> get productsBox => Hive.box<Product>(productsBoxName);
  static Box<Sale> get salesBox => Hive.box<Sale>(salesBoxName);
  static Box<InventoryChange> get inventoryChangesBox => Hive.box<InventoryChange>(inventoryChangesBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}