import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/sync_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final productProvider = context.read<ProductProvider>();
    final salesProvider = context.read<SalesProvider>();
    
    await Future.wait([
      productProvider.loadProducts(),
      salesProvider.loadSales(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Sync status
          Consumer<SyncProvider>(
            builder: (context, syncProvider, child) {
              return IconButton(
                icon: syncProvider.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        syncProvider.isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: syncProvider.isOnline ? Colors.green : Colors.orange,
                      ),
                onPressed: () {
                  if (!syncProvider.isSyncing) {
                    syncProvider.sync();
                  }
                },
                tooltip: syncProvider.getSyncStatusText(),
              );
            },
          ),
          
          // Profile menu
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton(
                icon: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    authProvider.displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(authProvider.displayName),
                      subtitle: Text(authProvider.email),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    onTap: () => context.goNamed('settings'),
                    child: const ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    onTap: () => authProvider.signOut(),
                    child: const ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Sign Out'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back, ${authProvider.displayName}!',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.dashboard,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Today's statistics
              Consumer<SalesProvider>(
                builder: (context, salesProvider, child) {
                  final todaysTotal = salesProvider.getTodaysTotal();
                  final todaysSalesCount = salesProvider.getTodaysSalesCount();
                  
                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: "Today's Sales",
                          value: '\$${todaysTotal.toStringAsFixed(2)}',
                          subtitle: '$todaysSalesCount transaction${todaysSalesCount != 1 ? 's' : ''}',
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Consumer<ProductProvider>(
                          builder: (context, productProvider, child) {
                            final lowStockCount = productProvider.lowStockCount;
                            return _StatCard(
                              title: 'Low Stock',
                              value: lowStockCount.toString(),
                              subtitle: 'item${lowStockCount != 1 ? 's' : ''} low',
                              icon: Icons.warning,
                              color: lowStockCount > 0 ? Colors.orange : Colors.blue,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 8),
              
              Consumer<ProductProvider>(
                builder: (context, productProvider, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Products',
                          value: productProvider.totalProducts.toString(),
                          subtitle: 'in inventory',
                          icon: Icons.inventory,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'Inventory Value',
                          value: '\$${productProvider.totalInventoryValue.toStringAsFixed(0)}',
                          subtitle: 'total value',
                          icon: Icons.account_balance_wallet,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Quick actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: [
                  _QuickActionCard(
                    title: 'New Sale',
                    icon: Icons.shopping_cart,
                    color: Colors.green,
                    onTap: () => context.goNamed('sales'),
                  ),
                  _QuickActionCard(
                    title: 'Scan Product',
                    icon: Icons.qr_code_scanner,
                    color: Colors.blue,
                    onTap: () => context.goNamed('scanner'),
                  ),
                  _QuickActionCard(
                    title: 'Add Product',
                    icon: Icons.add_box,
                    color: Colors.orange,
                    onTap: () => context.goNamed('add-product'),
                  ),
                  _QuickActionCard(
                    title: 'View Products',
                    icon: Icons.inventory,
                    color: Colors.purple,
                    onTap: () => context.goNamed('products'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Recent sales
              Consumer<SalesProvider>(
                builder: (context, salesProvider, child) {
                  final recentSales = salesProvider.getTodaySales().take(5).toList();
                  
                  if (recentSales.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No sales today',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start your first sale to see it here',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context.goNamed('sales'),
                              child: const Text('Start New Sale'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Sales',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.goNamed('sales-history'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentSales.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sale = recentSales[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.receipt,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              title: Text('\$${sale.total.toStringAsFixed(2)}'),
                              subtitle: Text(
                                '${sale.items.length} item${sale.items.length != 1 ? 's' : ''} • ${DateFormat('HH:mm').format(sale.createdAt)}',
                              ),
                              trailing: Chip(
                                label: Text(
                                  sale.paymentMethod.toString().split('.').last.toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: theme.colorScheme.secondaryContainer,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}