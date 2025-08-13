import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../models/sale.dart';
import '../../../providers/providers.dart';

import '../scan/scan_screen.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final List<SaleItem> _items = [];
  final TextEditingController _searchController = TextEditingController();
  double _orderDiscount = 0.0;
  double _taxRatePercent = 0.0;

  void _addProduct(Product p) {
    final idx = _items.indexWhere((i) => i.productId == p.id);
    if (idx >= 0) {
      final existing = _items[idx];
      setState(() => _items[idx] = existing.copyWith(quantity: existing.quantity + 1));
    } else {
      setState(() => _items.add(SaleItem(productId: p.id, name: p.name, quantity: 1, unitPrice: p.price)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsRepo = ref.watch(productRepositoryProvider);
    final matches = productsRepo.searchByNameOrBarcode(_searchController.text).toList();

    final subtotal = _items.fold<double>(0.0, (s, i) => s + i.lineSubtotal) - _orderDiscount;
    final tax = subtotal * (_taxRatePercent / 100.0);
    final total = subtotal + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
              if (code == null) return;
              final p = productsRepo.getByBarcode(code);
              if (p != null) _addProduct(p);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final p = matches[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ActionChip(
                      label: Text(p.name),
                      onPressed: () => _addProduct(p),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('Unit: ${item.unitPrice.toStringAsFixed(2)}  Qty: ${item.quantity}  Line: ${item.lineTotal.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () {
                        if (item.quantity > 1) {
                          setState(() => _items[index] = item.copyWith(quantity: item.quantity - 1));
                        } else {
                          setState(() => _items.removeAt(index));
                        }
                      }, icon: const Icon(Icons.remove_circle_outline)),
                      IconButton(onPressed: () {
                        setState(() => _items[index] = item.copyWith(quantity: item.quantity + 1));
                      }, icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Order discount'),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      decoration: const InputDecoration(prefixText: ''),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => setState(() => _orderDiscount = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tax %'),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      decoration: const InputDecoration(suffixText: '%'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => setState(() => _taxRatePercent = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Subtotal'),
                  Text(subtotal.toStringAsFixed(2)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tax'),
                  Text(tax.toStringAsFixed(2)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _items.isEmpty
                      ? null
                      : () async {
                          final payments = await _showPaymentDialog(context, total);
                          if (payments == null) return;
                          final saleRepo = ref.read(salesRepositoryProvider);
                          await saleRepo.createSale(
                            items: _items,
                            orderDiscount: _orderDiscount,
                            taxRatePercent: _taxRatePercent,
                            cashPaid: payments.cash,
                            cardPaid: payments.card,
                            mobileMoneyPaid: payments.mobile,
                          );
                          if (mounted) Navigator.pop(context);
                        },
                  child: const Text('Checkout'),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<_Payments?> _showPaymentDialog(BuildContext context, double amount) async {
    final cash = TextEditingController(text: '0');
    final card = TextEditingController(text: '0');
    final mobile = TextEditingController(text: '0');
    return showDialog<_Payments>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pay ${amount.toStringAsFixed(2)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: cash, decoration: const InputDecoration(labelText: 'Cash')), 
            TextField(controller: card, decoration: const InputDecoration(labelText: 'Card')), 
            TextField(controller: mobile, decoration: const InputDecoration(labelText: 'Mobile money')), 
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _Payments(
                    cash: double.tryParse(cash.text.trim()) ?? 0.0,
                    card: double.tryParse(card.text.trim()) ?? 0.0,
                    mobile: double.tryParse(mobile.text.trim()) ?? 0.0,
                  ),
                );
              },
              child: const Text('Confirm')),
        ],
      ),
    );
  }
}

class _Payments {
  final double cash;
  final double card;
  final double mobile;
  _Payments({required this.cash, required this.card, required this.mobile});
}