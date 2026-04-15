import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final checkoutAddressesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return [];

  final data = await Supabase.instance.client
      .from('addresses')
      .select()
      .eq('user_id', session.user.id)
      .order('is_default', ascending: false)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(data);
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _PaymentMethod { razorpay, cod }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _step = 0; // 0=address, 1=review, 2=payment
  bool _loading = false;
  _PaymentMethod _selectedPaymentMethod = _PaymentMethod.razorpay;
  late Razorpay _razorpay;

  // Address selection
  Map<String, dynamic>? _selectedAddress;
  bool _showManualEntry = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(child: _buildStepContent()),
            _buildBottomCTA(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step > 0) {
                setState(() => _step--);
              } else {
                context.pop();
              }
            },
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          const Text('CHECKOUT',
              style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['DELIVERY', 'REVIEW', 'PAYMENT'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 2,
                        color: isDone || isActive
                            ? Colors.white
                            : AppColors.outlineVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(steps[i],
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 9,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? Colors.white
                                : isDone
                                    ? AppColors.secondary
                                    : AppColors.outlineVariant,
                          )),
                    ],
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: [
        _buildAddressStep(),
        _buildReviewStep(),
        _buildPaymentStep(),
      ][_step],
    );
  }

  Widget _buildAddressStep() {
    final addressesAsync = ref.watch(checkoutAddressesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DELIVERY ADDRESS',
            style: TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: Colors.white)),
        const SizedBox(height: 32),

        // Saved Addresses Section
        addressesAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text('Error loading addresses: $e',
                style: TextStyle(color: AppColors.error)),
          ),
          data: (addresses) {
            if (addresses.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECT SAVED ADDRESS',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        letterSpacing: 3,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ...addresses.map((address) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AddressOption(
                        address: address,
                        isSelected: _selectedAddress?['id'] == address['id'],
                        onTap: () => _selectAddress(address),
                      ),
                    )),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        // Manual Entry Toggle
        Row(
          children: [
            Checkbox(
              value: _showManualEntry,
              onChanged: (value) {
                setState(() {
                  _showManualEntry = value ?? false;
                  if (!_showManualEntry) {
                    _selectedAddress = null;
                  }
                });
              },
              activeColor: AppColors.onPrimary,
            ),
            const SizedBox(width: 12),
            const Text('ENTER ADDRESS MANUALLY',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),

        const SizedBox(height: 24),

        // Manual Entry Form
        if (_showManualEntry) ...[
          _field(_nameCtrl, 'FULL NAME', 'Your Name'),
          const SizedBox(height: 24),
          _field(_phoneCtrl, 'PHONE NUMBER', '00000 00000',
              type: TextInputType.phone),
          const SizedBox(height: 24),
          _field(_line1Ctrl, 'ADDRESS LINE 1', 'Street, Building, Area'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _field(_cityCtrl, 'CITY', 'City')),
              const SizedBox(width: 16),
              Expanded(child: _field(_stateCtrl, 'STATE', 'State')),
            ],
          ),
          const SizedBox(height: 24),
          _field(_pincodeCtrl, 'PINCODE', '000000', type: TextInputType.number),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saveAddress,
              child: const Text('SAVE ADDRESS'),
            ),
          ),
        ] else if (_selectedAddress == null) ...[
          // No address selected message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('Please select a saved address or enter manually',
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant)),
            ),
          ),
        ],
      ],
    );
  }

  void _selectAddress(Map<String, dynamic> address) {
    setState(() {
      _selectedAddress = address;
      _showManualEntry = false;
    });
  }

  Future<void> _saveAddress() async {
    // Validate fields
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _line1Ctrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _stateCtrl.text.trim().isEmpty ||
        _pincodeCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please fill in all address fields.',
                style: TextStyle(fontFamily: 'Manrope'))));
      }
      return;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      await Supabase.instance.client.from('addresses').insert({
        'user_id': session.user.id,
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'line_1': _line1Ctrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'is_default': false,
      });

      // Refresh addresses and select the new one
      ref.invalidate(checkoutAddressesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Address saved successfully.',
                style: TextStyle(fontFamily: 'Manrope'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving address: $e',
                style: const TextStyle(fontFamily: 'Manrope'))));
      }
    }
  }

  Widget _buildReviewStep() {
    return FutureBuilder(
      future: _loadCartItems(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        double subtotal = 0;
        for (final item in items) {
          final product = item['products'] as Map<String, dynamic>;
          subtotal += (product['price'] as num) * (item['quantity'] as int);
        }
        final shipping = subtotal >= 999 ? 0.0 : 49.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ORDER REVIEW',
                style: TextStyle(
                    fontFamily: 'Epilogue',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text('${_nameCtrl.text} • ${_cityCtrl.text}, ${_stateCtrl.text}',
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: AppColors.outline)),
            const SizedBox(height: 32),
            ...items.map((item) {
              final product = item['products'] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Container(
                        width: 56,
                        height: 70,
                        color: AppColors.bg2,
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.outlineVariant, size: 24)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((product['name'] as String).toUpperCase(),
                              style: const TextStyle(
                                  fontFamily: 'Epilogue',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('QTY: ${item['quantity']}',
                              style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: AppColors.outline)),
                        ],
                      ),
                    ),
                    Text(
                        '₹${((product['price'] as num) * (item['quantity'] as int)).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            Container(
                height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
            const SizedBox(height: 16),
            _summaryRow('SUBTOTAL', '₹${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _summaryRow(
                'DELIVERY', shipping == 0 ? 'COMPLIMENTARY' : '₹$shipping'),
            const SizedBox(height: 16),
            Container(
                height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(
                        fontFamily: 'Epilogue',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text('₹${(subtotal + shipping).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontFamily: 'Epilogue',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAYMENT',
            style: TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: Colors.white)),
        const SizedBox(height: 32),
        _paymentOption(
          _PaymentMethod.razorpay,
          'Razorpay',
          'Credit / Debit Card, UPI, NetBanking',
          Icons.payment_outlined,
          selected: _selectedPaymentMethod == _PaymentMethod.razorpay,
        ),
        const SizedBox(height: 12),
        _paymentOption(
          _PaymentMethod.cod,
          'Cash on Delivery',
          'Pay when your order arrives',
          Icons.money_outlined,
          selected: _selectedPaymentMethod == _PaymentMethod.cod,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.bg2,
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 16),
              SizedBox(width: 12),
              Text('YOUR PAYMENT IS SECURED WITH 256-BIT ENCRYPTION',
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 9,
                      letterSpacing: 1.5,
                      color: AppColors.outline,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentOption(
      _PaymentMethod method, String title, String subtitle, IconData icon,
      {bool selected = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? Colors.white : AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          color: AppColors.outline)),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? Colors.white : AppColors.outlineVariant,
                    width: 2),
                color: selected ? Colors.white : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      color: AppColors.onPrimary, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCTA() {
    final labels = ['CONTINUE TO REVIEW', 'CONFIRM & PAY', 'PLACE ORDER'];
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      child: GestureDetector(
        onTap: _loading ? null : _handleCTA,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 56,
          color: _loading ? AppColors.bg4 : Colors.white,
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(labels[_step],
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: AppColors.onPrimary)),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCTA() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }

    // Validate address selection
    if (_selectedAddress == null && !_showManualEntry) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select a delivery address.',
                style: TextStyle(fontFamily: 'Manrope'))));
      }
      return;
    }

    // If manual entry is selected, validate fields
    if (_showManualEntry) {
      if (_nameCtrl.text.trim().isEmpty ||
          _phoneCtrl.text.trim().isEmpty ||
          _line1Ctrl.text.trim().isEmpty ||
          _cityCtrl.text.trim().isEmpty ||
          _stateCtrl.text.trim().isEmpty ||
          _pincodeCtrl.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please fill in all address fields.',
                  style: TextStyle(fontFamily: 'Manrope'))));
        }
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession!;
      final cartItems = await _loadCartItems();
      if (cartItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Your cart is empty.',
                  style: TextStyle(fontFamily: 'Manrope'))));
        }
        return;
      }

      double subtotal = 0;
      for (final item in cartItems) {
        final product = item['products'] as Map<String, dynamic>;
        subtotal += (product['price'] as num) * (item['quantity'] as int);
      }
      final shipping = subtotal >= AppConstants.freeShippingThreshold
          ? 0.0
          : AppConstants.shippingFee;

      if (_selectedPaymentMethod == _PaymentMethod.razorpay) {
        debugPrint('Starting Razorpay payment');
        await _startRazorpayPayment(cartItems, subtotal, shipping);
        return;
      }

      debugPrint('Placing COD order');
      await _placeOrder(
        session.user.id,
        cartItems,
        subtotal,
        shipping,
        paymentMethod: 'cod',
        paymentStatus: 'pending',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e',
                style: const TextStyle(fontFamily: 'Manrope'))));
      }
    } finally {
      if (mounted && _selectedPaymentMethod != _PaymentMethod.razorpay) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startRazorpayPayment(List<Map<String, dynamic>> cartItems,
      double subtotal, double shipping) async {
    final options = {
      'key': AppConstants.razorpayKeyId,
      'amount': ((subtotal + shipping) * 100).toInt(),
      'name': AppConstants.appName,
      'description': 'Order payment',
      'prefill': {
        'contact': _selectedAddress?['phone'] ?? _phoneCtrl.text,
        'name': _selectedAddress?['full_name'] ?? _nameCtrl.text,
      },
      'currency': AppConstants.appCurrency,
      'theme': {'color': '#000000'},
    };

    debugPrint('Opening Razorpay with options: $options');

    try {
      _razorpay.open(options);
      debugPrint('Razorpay opened successfully');
    } catch (e) {
      debugPrint('Razorpay open failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Payment failed: $e',
                style: const TextStyle(fontFamily: 'Manrope'))));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _placeOrder(String userId, List<Map<String, dynamic>> cartItems,
      double subtotal, double shipping,
      {required String paymentMethod,
      required String paymentStatus,
      String? transactionId}) async {
    final orderData = {
      'user_id': userId,
      'subtotal': subtotal,
      'shipping_fee': shipping,
      'total': subtotal + shipping,
      'status': 'confirmed',
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
    };

    // Only include transaction_id if it's not null
    if (transactionId != null) {
      orderData['transaction_id'] = transactionId;
    }

    debugPrint('Placing order with data: $orderData');

    final order = await Supabase.instance.client
        .from('orders')
        .insert(orderData)
        .select()
        .single();

    debugPrint('Order created: ${order['id']}');

    for (final item in cartItems) {
      final product = item['products'] as Map<String, dynamic>;
      await Supabase.instance.client.from('order_items').insert({
        'order_id': order['id'],
        'product_id': product['id'],
        'product_name': product['name'],
        'quantity': item['quantity'],
        'unit_price': product['price'],
        'total_price': (product['price'] as num) * (item['quantity'] as int),
      });
    }

    debugPrint('Order items created');

    await Supabase.instance.client.from('cart').delete().eq('user_id', userId);

    debugPrint('Cart cleared');

    if (mounted) {
      setState(() => _loading = false);
      context.go('/orders');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final cartItems = await _loadCartItems();
    if (cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your cart is empty.',
                style: TextStyle(fontFamily: 'Manrope'))));
      }
      return;
    }

    double subtotal = 0;
    for (final item in cartItems) {
      final product = item['products'] as Map<String, dynamic>;
      subtotal += (product['price'] as num) * (item['quantity'] as int);
    }
    final shipping = subtotal >= AppConstants.freeShippingThreshold
        ? 0.0
        : AppConstants.shippingFee;

    try {
      await _placeOrder(
        session.user.id,
        cartItems,
        subtotal,
        shipping,
        paymentMethod: 'razorpay',
        paymentStatus: 'paid',
        transactionId: response.paymentId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment successful.',
                style: TextStyle(fontFamily: 'Manrope'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Order save failed: $e',
                style: const TextStyle(fontFamily: 'Manrope'))));
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment error: ${response.code} ${response.message}',
            style: const TextStyle(fontFamily: 'Manrope'))));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('External wallet selected: ${response.walletName}',
            style: const TextStyle(fontFamily: 'Manrope'))));
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(
          fontFamily: 'Manrope', color: Colors.white, fontSize: 14),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                letterSpacing: 2,
                color: AppColors.secondary,
                fontWeight: FontWeight.w700)),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadCartItems() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return [];
    final data = await Supabase.instance.client
        .from('cart')
        .select('*, products(id, name, price, images)')
        .eq('user_id', session.user.id);
    return List<Map<String, dynamic>>.from(data);
  }
}

class _AddressOption extends StatelessWidget {
  final Map<String, dynamic> address;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressOption({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDefault = address['is_default'] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.onPrimary.withOpacity(0.1) : AppColors.bg2,
          border: Border.all(
              color:
                  isSelected ? AppColors.onPrimary : AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
              activeColor: AppColors.onPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(address['full_name'] as String,
                          style: const TextStyle(
                              fontFamily: 'Epilogue',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.onPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('DEFAULT',
                              style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onPrimary,
                                  letterSpacing: 1)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${address['line_1']}${address['line_2'] != null ? ', ${address['line_2']}' : ''}',
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.3)),
                  Text(
                      '${address['city']}, ${address['state']} ${address['pincode']}',
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(address['phone'] as String,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
