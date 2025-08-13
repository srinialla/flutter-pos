import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesRepositoryProvider).getAll().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Sales History')),
      body: ListView.separated(
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final s = sales[index];
          return ListTile(
            title: Text('Sale ${s.id.substring(0, 8)}'),
            subtitle: Text('${s.items.length} items  •  ${s.createdAt}'),
            trailing: Text(s.total.toStringAsFixed(2)),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
      ),
    );
  }
}