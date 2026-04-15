import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _statusSteps = ['confirmed', 'processing', 'shipped', 'delivered'];
  static const _statusLabels = ['ORDER CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED'];
  static const _statusIcons = [Icons.check_circle_outline, Icons.autorenew, Icons.local_shipping_outlined, Icons.home_outlined];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder(
        future: Supabase.instance.client
            .from('orders')
            .select('*, order_items(*, products(name, images))')
            .eq('id', orderId)
            .single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('Order not found',
              style: TextStyle(fontFamily: 'Manrope', color: AppColors.outline)));
          }
          final order = snapshot.data as Map<String, dynamic>;
          final items = order['order_items'] as List<dynamic>? ?? [];
          final status = order['status'] as String;
          final currentStep = _statusSteps.indexOf(status);

          return CustomScrollView(
            slivers: [
              SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Text(order['order_number'] as String? ?? 'ORDER',
                          style: const TextStyle(fontFamily: 'Epilogue', fontSize: 16,
                            fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              // Status Timeline
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER STATUS',
                        style: TextStyle(fontFamily: 'Manrope', fontSize: 9, letterSpacing: 3,
                          color: AppColors.outline, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 24),
                      Column(
                        children: List.generate(_statusSteps.length, (i) {
                          final done = i <= currentStep;
                          final active = i == currentStep;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    color: done ? Colors.white : AppColors.bg4,
                                    child: Icon(_statusIcons[i],
                                      color: done ? AppColors.onPrimary : AppColors.outlineVariant,
                                      size: 16),
                                  ),
                                  if (i < _statusSteps.length - 1)
                                    Container(width: 1, height: 40,
                                      color: done ? Colors.white.withOpacity(0.3) : AppColors.bg4),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_statusLabels[i],
                                      style: TextStyle(
                                        fontFamily: 'Manrope', fontSize: 11, letterSpacing: 2,
                                        fontWeight: FontWeight.w800,
                                        color: active ? Colors.white : done ? AppColors.secondary : AppColors.outlineVariant,
                                      )),
                                    if (active)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('CURRENT STATUS',
                                          style: TextStyle(fontFamily: 'Manrope', fontSize: 9,
                                            color: AppColors.outline, letterSpacing: 1)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              // Items
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ITEMS IN THIS ORDER',
                        style: TextStyle(fontFamily: 'Manrope', fontSize: 9, letterSpacing: 3,
                          color: AppColors.outline, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      ...items.map((it) {
                        final item = it as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          color: AppColors.bg2,
                          child: Row(
                            children: [
                              Container(width: 48, height: 60, color: AppColors.bg3,
                                child: const Icon(Icons.image_outlined,
                                  color: AppColors.outlineVariant, size: 20)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text((item['product_name'] as String).toUpperCase(),
                                      style: const TextStyle(fontFamily: 'Epilogue', fontSize: 12,
                                        fontWeight: FontWeight.w800, color: Colors.white),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('QTY: ${item['quantity']}',
                                      style: TextStyle(fontFamily: 'Manrope', fontSize: 10,
                                        letterSpacing: 1.5, color: AppColors.outline)),
                                  ],
                                ),
                              ),
                              Text('₹${item['total_price']}',
                                style: const TextStyle(fontFamily: 'Manrope', fontSize: 13,
                                  fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Summary
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(
                    children: [
                      Container(height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      _row('SUBTOTAL', '₹${order['subtotal']}'),
                      const SizedBox(height: 8),
                      _row('SHIPPING', order['shipping_fee'].toString() == '0.0' ? 'COMPLIMENTARY' : '₹${order['shipping_fee']}'),
                      const SizedBox(height: 16),
                      Container(height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                            style: TextStyle(fontFamily: 'Epilogue', fontSize: 18,
                              fontWeight: FontWeight.w900, color: Colors.white)),
                          Text('₹${order['total']}',
                            style: const TextStyle(fontFamily: 'Epilogue', fontSize: 22,
                              fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Manrope', fontSize: 11,
          letterSpacing: 2, color: AppColors.secondary, fontWeight: FontWeight.w700)),
        Text(value, style: const TextStyle(fontFamily: 'Manrope', fontSize: 13,
          fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }
}
