import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.outlineVariant),
                  const SizedBox(height: 24),
                  const Text('MY ORDERS',
                    style: TextStyle(fontFamily: 'Epilogue', fontSize: 22, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  Text('Sign in to view your order history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: AppColors.outline)),
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.go('/auth/login'),
                      child: const Text('SIGN IN'),
                    )),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MY ORDERS',
                      style: TextStyle(fontFamily: 'Epilogue', fontSize: 44,
                        fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('ORDER HISTORY',
                      style: TextStyle(fontFamily: 'Manrope', fontSize: 10, letterSpacing: 3,
                        color: AppColors.outline, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder(
              future: Supabase.instance.client
                  .from('orders')
                  .select('*, order_items(product_name, quantity, unit_price, product_image)')
                  .eq('user_id', user.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Colors.white),
                  ));
                }
                final orders = snapshot.data as List<dynamic>? ?? [];
                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.outlineVariant),
                          const SizedBox(height: 16),
                          Text('NO ORDERS YET',
                            style: TextStyle(fontFamily: 'Epilogue', fontSize: 18,
                              fontWeight: FontWeight.w800, color: AppColors.outline)),
                          const SizedBox(height: 20),
                          SizedBox(
                            child: ElevatedButton(
                              onPressed: () => context.go('/search'),
                              child: const Text('START SHOPPING'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: orders.map((o) => _OrderCard(order: o as Map<String, dynamic>)).toList(),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  static const _statusColors = {
    'pending': Color(0xFFFF9800),
    'confirmed': Color(0xFF2196F3),
    'processing': Color(0xFF9C27B0),
    'shipped': Color(0xFF00BCD4),
    'delivered': Color(0xFF4CAF50),
    'cancelled': Color(0xFFEF5350),
    'refunded': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String;
    final statusColor = _statusColors[status] ?? Colors.white;
    final orderDate = DateTime.parse(order['created_at'] as String).toLocal();
    final items = order['order_items'] as List<dynamic>? ?? [];

    return GestureDetector(
      onTap: () => context.push('/orders/${order['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        padding: const EdgeInsets.all(20),
        color: AppColors.bg2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order['order_number'] as String? ?? 'ORD',
                  style: const TextStyle(fontFamily: 'Epilogue', fontSize: 14,
                    fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: statusColor.withOpacity(0.15),
                  child: Text(status.toUpperCase(),
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 9, letterSpacing: 2,
                      fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${orderDate.day} ${_month(orderDate.month)} ${orderDate.year}',
              style: TextStyle(fontFamily: 'Manrope', fontSize: 10, letterSpacing: 2,
                color: AppColors.outline, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text('${items.length} item${items.length != 1 ? 's' : ''}',
              style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: AppColors.secondary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 10, letterSpacing: 2,
                    color: AppColors.outline, fontWeight: FontWeight.w700)),
                Text('₹${order['total']}',
                  style: const TextStyle(fontFamily: 'Epilogue', fontSize: 16,
                    fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _month(int m) => ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][m];
}
