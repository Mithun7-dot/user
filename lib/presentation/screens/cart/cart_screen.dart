import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

final cartItemsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return [];
  final data = await Supabase.instance.client
      .from('cart')
      .select('*, products(id, name, price, images, categories(name))')
      .eq('user_id', session.user.id);
  return List<Map<String, dynamic>>.from(data);
});

// Holds the currently applied coupon: { 'code': ..., 'discount_type': ..., 'discount_value': ... }
final cartCouponProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart when screen becomes visible again
    ref.invalidate(cartItemsProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh cart when app comes back to foreground
      ref.invalidate(cartItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartItemsProvider);
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return _buildGuestView(context);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: cartAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.white))),
        data: (items) {
          if (items.isEmpty) return _buildEmptyCart(context);
          return _buildCart(context, ref, items);
        },
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('YOUR BAG',
                      style: TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white)),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      color: AppColors.outlineVariant, size: 64),
                  const SizedBox(height: 24),
                  const Text('YOUR BAG IS EMPTY',
                      style: TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  const Text('Sign in to see your saved items',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          color: AppColors.outline)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.go('/auth/login'),
                      child: const Text('SIGN IN'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('CONTINUE SHOPPING'),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    color: AppColors.outlineVariant, size: 64),
                const SizedBox(height: 24),
                const Text('YOUR BAG IS EMPTY',
                    style: TextStyle(
                        fontFamily: 'Epilogue',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => context.go('/search'),
                    child: const Text('EXPLORE COLLECTION'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCart(
      BuildContext context, WidgetRef ref, List<Map<String, dynamic>> items) {
    double subtotal = 0;
    for (final item in items) {
      final product = item['products'] as Map<String, dynamic>;
      final qty = item['quantity'] as int;
      final price = (product['price'] as num).toDouble();
      subtotal += price * qty;
    }

    double discount = 0;
    final coupon = ref.watch(cartCouponProvider);
    if (coupon != null && subtotal >= (coupon['min_order_amount'] ?? 0)) {
      if (coupon['discount_type'] == 'percentage') {
        discount = subtotal * (coupon['discount_value'] / 100);
        if (coupon['max_discount'] != null &&
            discount > coupon['max_discount']) {
          discount = (coupon['max_discount'] as num).toDouble();
        }
      } else {
        discount = (coupon['discount_value'] as num).toDouble();
      }
    }

    final shippingFee = subtotal >= 999 ? 0.0 : 49.0;
    final total = subtotal - discount + shippingFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOUR BAG',
                        style: TextStyle(
                            fontFamily: 'Epilogue',
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: Colors.white,
                            height: 1)),
                    const SizedBox(height: 4),
                    Text(
                        '${items.length} ITEM${items.length > 1 ? 'S' : ''} SELECTED',
                        style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10,
                            letterSpacing: 3,
                            color: AppColors.outline,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CartItem(
                item: items[i],
                onRemove: () async {
                  await Supabase.instance.client
                      .from('cart')
                      .delete()
                      .eq('id', items[i]['id']);
                  ref.invalidate(cartItemsProvider);
                },
                onQuantityChange: (qty) async {
                  if (qty < 1) return;
                  await Supabase.instance.client
                      .from('cart')
                      .update({'quantity': qty}).eq('id', items[i]['id']);
                  ref.invalidate(cartItemsProvider);
                },
              ),
              childCount: items.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 1,
                      color: AppColors.outlineVariant.withOpacity(0.2)),
                  const SizedBox(height: 24),
                  const Text('ORDER SUMMARY',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 9,
                          letterSpacing: 4,
                          color: AppColors.outline,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _CouponSection(),
                  const SizedBox(height: 24),
                  _SummaryRow('SUBTOTAL', '₹${subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  if (discount > 0) ...[
                    _SummaryRow('DISCOUNT', '-₹${discount.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                  ],
                  _SummaryRow(
                      'DELIVERY',
                      shippingFee == 0
                          ? 'COMPLIMENTARY'
                          : '₹${shippingFee.toStringAsFixed(2)}'),
                  const SizedBox(height: 24),
                  Container(
                      height: 1,
                      color: AppColors.outlineVariant.withOpacity(0.1)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL AMOUNT',
                          style: TextStyle(
                              fontFamily: 'Epilogue',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                      Text('₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontFamily: 'Epilogue',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // PROCEED TO CHECKOUT — AUTH GATE
                  _ProceedToCheckoutButton(),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('ESTIMATED DELIVERY: 2-4 BUSINESS DAYS',
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 9,
                            letterSpacing: 2,
                            color: AppColors.outline,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _ProceedToCheckoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          // AUTH GATE: Show login bottom sheet before checkout
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _CheckoutAuthSheet(),
          );
        } else {
          context.push('/checkout');
        }
      },
      child: Container(
        width: double.infinity,
        height: 64,
        color: Colors.white,
        child: const Center(
          child: Text('PROCEED TO CHECKOUT',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  color: AppColors.onPrimary)),
        ),
      ),
    );
  }
}

class _CheckoutAuthSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg2,
      padding: EdgeInsets.fromLTRB(
          32, 40, 32, 40 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 40,
              height: 3,
              color: AppColors.outlineVariant,
              margin: const EdgeInsets.only(bottom: 32)),
          const Text('SIGN IN TO CHECKOUT',
              style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1)),
          const SizedBox(height: 12),
          const Text(
              'You need an account to place an order and track deliveries.',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/auth/login');
              },
              child: const Text('SIGN IN TO MY ACCOUNT'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/auth/register');
              },
              child: const Text('CREATE AN ACCOUNT'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChange;

  const _CartItem(
      {required this.item,
      required this.onRemove,
      required this.onQuantityChange});

  @override
  Widget build(BuildContext context) {
    final product = item['products'] as Map<String, dynamic>;
    final images = product['images'] as List<dynamic>?;
    final imageUrl =
        images != null && images.isNotEmpty ? images[0] as String : null;
    final qty = item['quantity'] as int;
    final price = product['price'] as num;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.32,
            height: 200,
            color: AppColors.bg2,
            child: imageUrl != null
                ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                : const Icon(Icons.image_outlined,
                    color: AppColors.outlineVariant, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text((product['name'] as String).toUpperCase(),
                          style: const TextStyle(
                              fontFamily: 'Epilogue',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2),
                          maxLines: 2),
                    ),
                    Text('₹${(price * qty).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontFamily: 'Epilogue',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 4),
                if (item['size'] != null)
                  Text('SIZE ${item['size']}',
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          letterSpacing: 2,
                          color: AppColors.outline,
                          fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QtyBtn(
                              Icons.remove, () => onQuantityChange(qty - 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Text(qty.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                          _QtyBtn(Icons.add, () => onQuantityChange(qty + 1)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onRemove,
                      child: const Text('REMOVE',
                          style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 44,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                letterSpacing: 2,
                color: AppColors.secondary,
                fontWeight: FontWeight.w700)),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ],
    );
  }
}

class _CouponSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends ConsumerState<_CouponSection> {
  final _couponCtrl = TextEditingController();
  bool _applying = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _applying = true;
      _message = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('coupons')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _message = 'Invalid or expired coupon code.';
          _isError = true;
          _applying = false;
        });
        return;
      }

      ref.read(cartCouponProvider.notifier).state = res;

      setState(() {
        _message = 'Coupon applied successfully!';
        _isError = false;
        _applying = false;
        _couponCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _message = 'Error verifying coupon.';
        _isError = true;
        _applying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCoupon = ref.watch(cartCouponProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeCoupon != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withOpacity(0.1),
              border: Border.all(color: AppColors.onPrimary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer_outlined,
                        color: AppColors.onPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(activeCoupon['code'] as String,
                        style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    ref.read(cartCouponProvider.notifier).state = null;
                    setState(() => _message = null);
                  },
                  child: const Icon(Icons.close,
                      color: AppColors.onPrimary, size: 18),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCtrl,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontFamily: 'Manrope'),
                  decoration: const InputDecoration(
                    hintText: 'ENTER COUPON CODE',
                    hintStyle: TextStyle(
                        color: AppColors.outline,
                        fontSize: 11,
                        letterSpacing: 2),
                    enabledBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: AppColors.outlineVariant)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _applying ? null : _applyCoupon,
                child: _applying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('APPLY',
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white)),
              ),
            ],
          ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  color: _isError ? AppColors.error : AppColors.onPrimary)),
        ]
      ],
    );
  }
}
