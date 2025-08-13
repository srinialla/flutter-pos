import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../providers/providers.dart';

import 'product_form_screen.dart';
import '../scan/scan_screen.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(productRepositoryProvider);
    final products = repo.searchByNameOrBarcode(_query).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
              if (code == null) return;
              final found = repo.getByBarcode(code);
              if (found != null) {
                // In a full app, add to cart or open details. Here: open edit.
                if (context.mounted) {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ProductFormScreen(existing: found)));
                  setState(() {});
                }
              } else {
                if (context.mounted) {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProductFormScreen(initialBarcode: code)));
                  setState(() {});
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or barcode'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: products.length,
              itemBuilder: (context, index) => _ProductTile(product: products[index]),
              separatorBuilder: (_, __) => const Divider(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(productRepositoryProvider);
    return ListTile(
      title: Text(product.name),
      subtitle: Text('Price: ${product.price.toStringAsFixed(2)} | Stock: ${product.stockQuantity}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductFormScreen(existing: product)),
            );
            if (context.mounted) {
              // refresh by popping back
              (context as Element).markNeedsBuild();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await repo.delete(product.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
              (context as Element).markNeedsBuild();
            }
          },
        ),
      ]),
    );
  }
}