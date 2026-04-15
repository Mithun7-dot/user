import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final productDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final data = await Supabase.instance.client
      .from('products')
      .select('*, categories(name), product_variants(*)')
      .eq('id', id)
      .maybeSingle();
  return data;
});

final productReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, productId) async {
  final data = await Supabase.instance.client
      .from('reviews')
      .select('*, users(full_name)')
      .eq('product_id', productId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _imageIndex = 0;
  final PageController _pageController = PageController();
  String? _selectedSize;
  String? _selectedColor;
  bool _addingToCart = false;
  bool _inWishlist = false;


  @override
  void initState() {
    super.initState();
    _checkWishlist();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkWishlist() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      final data = await Supabase.instance.client
          .from('wishlist')
          .select('id')
          .eq('user_id', session.user.id)
          .eq('product_id', widget.productId)
          .maybeSingle();
      if (mounted) setState(() => _inWishlist = data != null);
    } catch (e) {
      debugPrint('Error checking wishlist: $e');
    }
  }

  Future<void> _toggleWishlist() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _showAuthBottomSheet();
      return;
    }
    setState(() => _inWishlist = !_inWishlist);
    try {
      if (_inWishlist) {
        await Supabase.instance.client.from('wishlist').insert({
          'user_id': session.user.id,
          'product_id': widget.productId,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Added to wishlist',
                  style: TextStyle(fontFamily: 'Manrope'))));
        }
      } else {
        await Supabase.instance.client
            .from('wishlist')
            .delete()
            .eq('user_id', session.user.id)
            .eq('product_id', widget.productId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Removed from wishlist',
                  style: TextStyle(fontFamily: 'Manrope'))));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _inWishlist = !_inWishlist); // revert
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync =
        ref.watch(productDetailProvider(widget.productId));
    final reviewsAsync =
        ref.watch(productReviewsProvider(widget.productId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: productAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white))),
        data: (product) {
          if (product == null) {
            return Center(
                child: Text('Product not found',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AppColors.outline)));
          }
          final images =
              (product['images'] as List<dynamic>?)?.cast<String>() ??
                  [];
          final variants =
              (product['product_variants'] as List<dynamic>?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
          final sizes = variants
              .map((v) => v['size'] as String?)
              .whereType<String>()
              .toSet()
              .toList();
          final colors =
              variants.where((v) => v['color'] != null).toList();
          final category =
              product['categories'] as Map<String, dynamic>?;

          // Average rating
          final reviews = reviewsAsync.valueOrNull ?? [];
          double avgRating = 0;
          if (reviews.isNotEmpty) {
            final total = reviews.fold<num>(
                0, (sum, r) => sum + (r['rating'] as num? ?? 0));
            avgRating = total / reviews.length;
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Image Carousel ─────────────────────────────────
                  SliverToBoxAdapter(
                      child: _buildImageCarousel(images)),
                  // ── Product Info ───────────────────────────────────
                  SliverToBoxAdapter(
                      child: _buildProductInfo(
                          product, category, avgRating, reviews.length)),
                  // ── Size Selector ──────────────────────────────────
                  if (sizes.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildSizeSelector(sizes)),
                  // ── Color Selector ─────────────────────────────────
                  if (colors.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildColorSelector(colors)),
                  // ── Description ────────────────────────────────────
                  SliverToBoxAdapter(
                      child: _buildDescription(product)),

                  // ── Customer Reviews ───────────────────────────────
                  SliverToBoxAdapter(
                      child: _buildReviewsSection(reviews)),
                  // ── Footer ─────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildFooter()),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              // ── Top Bar ─────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: AppColors.bg0.withOpacity(0.5),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/cart'),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: AppColors.bg0.withOpacity(0.5),
                            child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.white,
                                size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Bottom CTA ───────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.background.withOpacity(0.9),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Row(
                    children: [
                      // Wishlist button
                      GestureDetector(
                        onTap: _toggleWishlist,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _inWishlist
                                    ? Colors.red
                                    : AppColors.outlineVariant),
                          ),
                          child: Icon(
                            _inWishlist
                                ? Icons.favorite
                                : Icons.favorite_outline,
                            color: _inWishlist
                                ? Colors.red
                                : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _addingToCart ? null : () => _addToCart(product),
                          child: Container(
                            height: 56,
                            color: AppColors.bg4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_addingToCart)
                                  const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                else ...[
                                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  const Text('BAG',
                                      style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2,
                                          color: Colors.white)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _addingToCart ? null : () => _buyNow(product),
                          child: Container(
                            height: 56,
                            color: Colors.white,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.flash_on, color: AppColors.onPrimary, size: 16),
                                const SizedBox(width: 6),
                                const Text('BUY NOW',
                                    style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: AppColors.onPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Image Carousel ──────────────────────────────────────────────────────────

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 480,
        color: AppColors.bg2,
        child: Center(
            child: Icon(Icons.image_outlined,
                color: AppColors.outlineVariant, size: 60)),
      );
    }
    return Stack(
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        // Thumbnail strip at bottom
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _imageIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 48 : 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: ClipRect(
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  // ── Product Info + Rating ────────────────────────────────────────────────────

  Widget _buildProductInfo(Map<String, dynamic> product,
      Map<String, dynamic>? category, double avgRating, int reviewCount) {
    final price = product['price'] as num;
    final comparePrice = product['compare_price'] as num?;
    final hasDiscount =
        comparePrice != null && comparePrice > price;
    final discountPct = hasDiscount
        ? (((comparePrice! - price) / comparePrice) * 100).round()
        : 0;
    final creditValue = product['credit_value'] as num? ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category != null)
            Text(
              (category['name'] as String).toUpperCase(),
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 8),
          Text(
            (product['name'] as String).toUpperCase(),
            style: const TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
                height: 1.1),
          ),
          const SizedBox(height: 12),
          // Star rating row
          if (reviewCount > 0)
            Row(
              children: [
                ...List.generate(5, (i) {
                  final full = i < avgRating.floor();
                  final half = !full && i < avgRating;
                  return Icon(
                    full
                        ? Icons.star
                        : half
                            ? Icons.star_half
                            : Icons.star_outline,
                    color: const Color(0xFFFFD700),
                    size: 16,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${avgRating.toStringAsFixed(1)} ($reviewCount review${reviewCount != 1 ? 's' : ''})',
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('₹${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontFamily: 'Epilogue',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              if (hasDiscount) ...[
                const SizedBox(width: 12),
                Text('₹${comparePrice!.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: AppColors.outline,
                        decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  color: Colors.white,
                  child: Text('$discountPct% OFF',
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.onPrimary)),
                ),
              ],
            ],
          ),
          // Credit reward badge
          if (creditValue > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Earn $creditValue credits on purchase',
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Size Selector ────────────────────────────────────────────────────────────

  Widget _buildSizeSelector(List<String> sizes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SELECT SIZE',
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      letterSpacing: 3,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => _buildSizeGuideModal(context),
                  );
                },
                child: Text('SIZE GUIDE',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        color: AppColors.outline,
                        letterSpacing: 2,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.outline)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sizes.map((size) {
              final sel = _selectedSize == size;
              return GestureDetector(
                onTap: () => setState(() => _selectedSize = size),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 60,
                  height: 52,
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: sel ? Colors.white : AppColors.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(size,
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? AppColors.onPrimary
                                : Colors.white)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Color Selector ───────────────────────────────────────────────────────────

  Widget _buildColorSelector(List<Map<String, dynamic>> colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT COLOR',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  letterSpacing: 3,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: colors.take(5).map((v) {
              final isSelected = _selectedColor == v['color'];
              final hex = v['color_hex'] as String?;
              Color c = Colors.grey;
              if (hex != null) {
                try {
                  c = Color(int.parse(
                      'FF${hex.replaceAll('#', '')}',
                      radix: 16));
                } catch (_) {}
              }
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedColor = v['color']),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : AppColors.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Description ──────────────────────────────────────────────────────────────

  Widget _buildDescription(Map<String, dynamic> product) {
    final desc = product['description'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DETAILS',
              style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2)),
          Container(
              height: 1,
              color: AppColors.outlineVariant,
              margin: const EdgeInsets.symmetric(vertical: 16)),
          Text(
            desc ?? 'No description available.',
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.7),
          ),
        ],
      ),
    );
  }
  // ── Reviews Section ──────────────────────────────────────────────────────────

  Widget _buildReviewsSection(List<Map<String, dynamic>> reviews) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('CUSTOMER REVIEWS',
                  style: TextStyle(
                      fontFamily: 'Epilogue',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                color: AppColors.bg4,
                child: Text('${reviews.length}',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          Container(
              height: 1,
              color: AppColors.outlineVariant,
              margin: const EdgeInsets.symmetric(vertical: 16)),
          if (reviews.isEmpty)
            Text('No reviews yet. Be the first to review!',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: AppColors.outlineVariant))
          else
            ...reviews.map((r) => _ReviewCard(review: r)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      color: AppColors.bg0,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerLink('FREE RETURNS', null),
                    _footerLink('SECURE PAYMENT', null),
                    _footerLink('SHOP ALL', () => context.go('/search')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerLink('CONTACT US', null),
                    _footerLink('SIZE GUIDE', null),
                    _footerLink('MY ORDERS', () => context.go('/orders')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} Rockstar. All rights reserved.',
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                letterSpacing: 1,
                color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.onSurfaceVariant)),
      ),
    );
  }

  // ── Add to Cart ──────────────────────────────────────────────────────────────

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) _showAuthBottomSheet();
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await _upsertCartItem(session.user.id, product['id'], size: _selectedSize);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Added to bag',
                  style: TextStyle(fontFamily: 'Manrope'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e',
                  style: const TextStyle(fontFamily: 'Manrope'))),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  /// Inserts a new cart row or increments quantity if one already exists.
  /// Uses an explicit select-then-insert/update pattern because the unique
  /// index on (user_id, product_id, variant_id) does NOT match NULLs in
  /// Postgres, so generic upsert with onConflict fails for NULL variant_id.
  Future<void> _upsertCartItem(String userId, String productId, {String? size}) async {
    final existing = await Supabase.instance.client
        .from('cart')
        .select('id, quantity')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .isFilter('variant_id', null)
        .maybeSingle();

    if (existing != null) {
      final newQty = (existing['quantity'] as int) + 1;
      await Supabase.instance.client
          .from('cart')
          .update({'quantity': newQty, 'size': size})
          .eq('id', existing['id']);
    } else {
      await Supabase.instance.client.from('cart').insert({
        'user_id': userId,
        'product_id': productId,
        'quantity': 1,
        if (size != null) 'size': size,
      });
    }
  }

  Future<void> _buyNow(Map<String, dynamic> product) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) _showAuthBottomSheet();
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await _upsertCartItem(session.user.id, product['id'],
          size: _selectedSize);
      if (mounted) {
        context.go('/cart');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e',
                  style: const TextStyle(fontFamily: 'Manrope'))),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Widget _buildSizeGuideModal(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      color: AppColors.bg0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SIZE GUIDE',
                    style: TextStyle(
                        fontFamily: 'Epilogue',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HOW TO MEASURE',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  const Text(
                    'Use a tape measure to take your measurements. Keep the tape measure level and comfortably loose.',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: AppColors.onSurface,
                        height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  _buildSizeRow('S', '36"', '30"'),
                  _buildSizeRow('M', '38"', '32"'),
                  _buildSizeRow('L', '40"', '34"'),
                  _buildSizeRow('XL', '42"', '36"'),
                  _buildSizeRow('XXL', '44"', '38"'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeRow(String size, String chest, String waist) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(size,
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CHEST',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        color: AppColors.outline)),
                Text(chest,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: AppColors.onSurface)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WAIST',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        color: AppColors.outline)),
                Text(waist,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAuthBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AuthBottomSheet(onSuccess: () {
        Navigator.pop(context);
      }),
    );
  }
}

// ── Review Card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as num? ?? 0;
    final comment = review['comment'] as String? ?? '';
    final user = review['users'] as Map<String, dynamic>?;
    final name = user?['full_name'] as String? ?? 'Anonymous';
    final date = review['created_at'] != null
        ? DateTime.parse(review['created_at'] as String).toLocal()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      color: AppColors.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name.toUpperCase(),
                  style: const TextStyle(
                      fontFamily: 'Epilogue',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              if (date != null)
                Text('${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        color: AppColors.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star : Icons.star_outline,
                color: const Color(0xFFFFD700),
                size: 14,
              ),
            ),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.6)),
          ],
        ],
      ),
    );
  }
}

// ── Auth Bottom Sheet ────────────────────────────────────────────────────────

class _AuthBottomSheet extends StatelessWidget {
  final VoidCallback onSuccess;
  const _AuthBottomSheet({required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg2,
      padding: EdgeInsets.fromLTRB(
          32, 32, 32, 32 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SIGN IN TO CONTINUE',
              style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(
              'Create an account or sign in to add items to your bag.',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/auth/login');
              },
              child: const Text('SIGN IN'),
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
              child: const Text('CREATE ACCOUNT'),
            ),
          ),
        ],
      ),
    );
  }
}
