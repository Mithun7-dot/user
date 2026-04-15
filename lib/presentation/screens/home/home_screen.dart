import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final categoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('categories')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(data);
});

final featuredProductsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('products')
      .select('*, categories(name)')
      .eq('is_active', true)
      .eq('is_featured', true)
      .order('created_at', ascending: false)
      .limit(10);
  return List<Map<String, dynamic>>.from(data);
});

/// Products per category — returns a map of categoryId → list of products
final productsByCategoryProvider =
    FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final cats = await ref.watch(categoriesProvider.future);
  final result = <String, List<Map<String, dynamic>>>{};
  for (final cat in cats) {
    final catId = cat['id'] as String;
    final data = await Supabase.instance.client
        .from('products')
        .select('*, categories(name)')
        .eq('is_active', true)
        .eq('category_id', catId)
        .order('created_at', ascending: false)
        .limit(10);
    final products = List<Map<String, dynamic>>.from(data);
    if (products.isNotEmpty) result[catId] = products;
  }
  return result;
});

final bannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('banners')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

/// Discover strips — horizontal scrolling featured images with CTA button
final featuredStripsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('featured_strips')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

// ── Icon mapping for category icon_name → IconData ──────────────────────────
IconData _categoryIcon(String? iconName) {
  switch (iconName) {
    case 'layers_outlined':
      return Icons.layers_outlined;
    case 'local_offer_outlined':
      return Icons.local_offer_outlined;
    case 'dry_cleaning_outlined':
      return Icons.dry_cleaning_outlined;
    case 'checkroom_outlined':
      return Icons.checkroom_outlined;
    case 'watch_outlined':
      return Icons.watch_outlined;
    case 'directions_walk_outlined':
      return Icons.directions_walk_outlined;
    case 'shopping_bag_outlined':
      return Icons.shopping_bag_outlined;
    case 'face_outlined':
      return Icons.face_outlined;
    case 'sports_outlined':
      return Icons.sports_outlined;
    case 'star_outline':
      return Icons.star_outline;
    case 'diamond_outlined':
      return Icons.diamond_outlined;
    case 'color_lens_outlined':
      return Icons.color_lens_outlined;
    case 'emoji_nature_outlined':
      return Icons.emoji_nature_outlined;
    case 'weekend_outlined':
      return Icons.weekend_outlined;
    case 'beach_access_outlined':
      return Icons.beach_access_outlined;
    case 'luggage_outlined':
      return Icons.luggage_outlined;
    case 'wc_outlined':
      return Icons.wc_outlined;
    case 'child_care_outlined':
      return Icons.child_care_outlined;
    case 'fitness_center_outlined':
      return Icons.fitness_center_outlined;
    default:
      return Icons.category_outlined;
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _heroBannerIndex = 0;
  final PageController _heroController = PageController();

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  /// Pull-to-refresh: invalidates all home screen providers and awaits reload.
  Future<void> _refreshAll() async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(featuredProductsProvider);
    ref.invalidate(productsByCategoryProvider);
    ref.invalidate(bannersProvider);
    ref.invalidate(featuredStripsProvider);
    try {
      await ref.read(bannersProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsByCatAsync = ref.watch(productsByCategoryProvider);
    final bannersAsync = ref.watch(bannersProvider);
    final stripsAsync = ref.watch(featuredStripsProvider);

    final screenW = MediaQuery.of(context).size.width;
    // Responsive horizontal padding — tighter on phones
    final hPad = screenW < 400 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: Colors.white,
        backgroundColor: AppColors.bg2,
        displacement: 80,
        child: CustomScrollView(
          // Required so RefreshIndicator works even when content fits screen
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context),

            // ── Hero banner carousel ────────────────────────────────────────
            SliverToBoxAdapter(
                child: _buildAdCarouselBanner(bannersAsync, screenW)),

            // ── Discover strip (horizontal scrolling image cards) ───────────
            SliverToBoxAdapter(
                child: _buildDiscoverStrip(stripsAsync, screenW, hPad)),

            // ── Categories icon row ─────────────────────────────────────────
            SliverToBoxAdapter(child: _buildCategories(categoriesAsync, hPad)),

            // ── Products by category ────────────────────────────────────────
            ...productsByCatAsync.when(
              loading: () => [
                SliverToBoxAdapter(
                  child:
                      _buildSectionHeader('ESSENTIALS', 'EXPLORE', hPad: hPad),
                ),
                SliverToBoxAdapter(child: _buildLoadingRow(hPad, screenW)),
              ],
              error: (_, __) => [],
              data: (productsByCategory) {
                final slivers = <Widget>[];
                final cats = categoriesAsync.valueOrNull ?? [];
                for (final cat in cats) {
                  final catId = cat['id'] as String;
                  final products = productsByCategory[catId];
                  if (products == null || products.isEmpty) continue;
                  slivers.add(SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      (cat['name'] as String).toUpperCase(),
                      'VIEW ALL',
                      hPad: hPad,
                      onTap: () => context.go('/search?categoryId=$catId'),
                    ),
                  ));
                  slivers.add(SliverToBoxAdapter(
                      child: _buildProductsRow(products, screenW, hPad)));
                }
                return slivers;
              },
            ),

            SliverToBoxAdapter(child: _buildEditorialSection(screenW, hPad)),
            SliverToBoxAdapter(child: _buildFooter(hPad)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      pinned: true,
      elevation: 0,
      toolbarHeight: 64,
      leading: IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: () => context.go('/search'),
      ),
      title: const Text(
        'RockStar',
        style: TextStyle(
          fontFamily: 'Epilogue',
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: Colors.white),
          onPressed: () => context.go('/profile'),
        ),
      ],
    );
  }

  // ── Hero Banner ─────────────────────────────────────────────────────────────

  Widget _buildAdCarouselBanner(
      AsyncValue<List<Map<String, dynamic>>> bannersAsync, double screenW) {
    // Responsive height: smaller on compact phones
    final bannerH = screenW < 360
        ? 340.0
        : screenW < 480
            ? 440.0
            : 540.0;

    return bannersAsync.when(
      loading: () => SizedBox(
          height: bannerH,
          child: const Center(child: CircularProgressIndicator())),
      error: (_, __) => SizedBox(
        height: bannerH,
        child: const Center(
            child: Text('Error loading banners',
                style: TextStyle(color: Colors.white))),
      ),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            SizedBox(
              height: bannerH,
              child: PageView.builder(
                controller: _heroController,
                onPageChanged: (i) => setState(() => _heroBannerIndex = i),
                itemCount: banners.length,
                itemBuilder: (context, i) {
                  final banner = banners[i];
                  final imageUrl = banner['image_url'] as String?;
                  final actionUrl = banner['action_url'] as String?;
                  final ctaLabel =
                      (banner['cta_label'] as String?)?.toUpperCase() ??
                          'SHOP NOW';
                  final heroTitle = banner['title'] as String? ?? '';
                  final heroSubtitle = banner['subtitle'] as String? ?? '';
                  final isEditable = banner['is_editable'] as bool? ?? false;

                  return GestureDetector(
                    onLongPress: () => _showAdBannerDetails(context, banner),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.35),
                            colorBlendMode: BlendMode.darken,
                          )
                        else
                          Container(color: AppColors.bg2),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.background
                              ],
                              stops: [0.4, 1.0],
                            ),
                          ),
                        ),
                        if (isEditable)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () {
                                final bannerId = banner['id'] as String?;
                                if (bannerId != null) {
                                  context.go(
                                    AppConstants.routeBannerEditFor(bannerId),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.edit_outlined,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 36,
                          left: 24,
                          right: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                heroTitle,
                                style: TextStyle(
                                  fontFamily: 'Epilogue',
                                  fontSize: screenW < 380 ? 32 : 44,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  color: Colors.white,
                                ),
                              ),
                              if (heroSubtitle.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  heroSubtitle.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              OutlinedButton(
                                onPressed:
                                    actionUrl != null && actionUrl.isNotEmpty
                                        ? () => context.go(actionUrl)
                                        : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Colors.white, width: 1.5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(0)),
                                ),
                                child: Text(
                                  ctaLabel,
                                  style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 28,
                  height: 2,
                  color: i == _heroBannerIndex
                      ? Colors.white
                      : AppColors.outlineVariant,
                );
              }),
            ),
          ],
        );
      },
    );
  }

  void _showAdBannerDetails(BuildContext context, Map<String, dynamic> banner) {
    final actionUrl = banner['action_url'] as String?;
    final isEditable = banner['is_editable'] as bool? ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                banner['title'] as String? ?? 'Banner Details',
                style: const TextStyle(
                    fontFamily: 'Epilogue',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              if ((banner['subtitle'] as String? ?? '').isNotEmpty)
                Text(
                  banner['subtitle'] as String,
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      height: 1.6),
                ),
              if (actionUrl != null && actionUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Action URL',
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        letterSpacing: 2,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(actionUrl,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        color: Colors.white)),
              ],
              const SizedBox(height: 24),
              if (isEditable) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      final bannerId = banner['id'] as String?;
                      if (bannerId != null) {
                        context.go(
                          AppConstants.routeBannerEditFor(bannerId),
                        );
                      }
                    },
                    child: const Text('EDIT BANNER'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: actionUrl != null && actionUrl.isNotEmpty
                      ? () {
                          Navigator.pop(context);
                          context.go(actionUrl);
                        }
                      : null,
                  child: const Text('OPEN BANNER LINK'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Discover Strip ──────────────────────────────────────────────────────────
  // Horizontal scrolling image cards loaded from `featured_strips` table.
  // Each card has: full-bleed image + gradient overlay + title + CTA button.

  Widget _buildDiscoverStrip(AsyncValue<List<Map<String, dynamic>>> stripsAsync,
      double screenW, double hPad) {
    return stripsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (strips) {
        if (strips.isEmpty) return const SizedBox.shrink();

        // Card dimensions — portrait ratio, adaptive width
        final cardW = min(screenW * 0.70, 260.0);
        final cardH = cardW * 1.45; // ~1:1.45 portrait

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            _buildSectionHeader('DISCOVER', 'VIEW ALL',
                hPad: hPad, onTap: () => context.go('/search')),
            const SizedBox(height: 16),
            SizedBox(
              height: cardH,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: strips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _DiscoverCard(
                  strip: strips[i],
                  width: cardW,
                  height: cardH,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Categories Row ──────────────────────────────────────────────────────────

  Widget _buildCategories(
      AsyncValue<List<Map<String, dynamic>>> categoriesAsync, double hPad) {
    return Padding(
      padding: const EdgeInsets.only(top: 48, bottom: 0),
      child: Column(
        children: [
          _buildSectionHeader('CATEGORIES', 'VIEW ALL',
              hPad: hPad, onTap: () => context.go('/search')),
          const SizedBox(height: 24),
          SizedBox(
            height: 88,
            child: categoriesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 1.5)),
              error: (_, __) => const SizedBox(),
              data: (cats) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 24),
                itemBuilder: (context, i) {
                  final cat = cats[i];
                  return GestureDetector(
                    onTap: () => context.go('/search?categoryId=${cat['id']}'),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.bg4,
                            border: Border.all(
                              color: AppColors.outlineVariant.withOpacity(0.3),
                            ),
                          ),
                          child: Icon(
                            _categoryIcon(cat['icon_name'] as String?),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (cat['name'] as String).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String action,
      {VoidCallback? onTap, double hPad = 24}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onTap ?? () => context.go('/search'),
            child: Text(
              action,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.secondary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading Skeleton Row ────────────────────────────────────────────────────

  Widget _buildLoadingRow(double hPad, double screenW) {
    final cardW = _productCardWidth(screenW);
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, __) => _ProductCardSkeleton(width: cardW),
      ),
    );
  }

  // ── Products Row ────────────────────────────────────────────────────────────

  Widget _buildProductsRow(
      List<Map<String, dynamic>> products, double screenW, double hPad) {
    final cardW = _productCardWidth(screenW);
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) =>
            _ProductCard(product: products[i], width: cardW),
      ),
    );
  }

  /// Adaptive product card width — never bigger than 220, never smaller than
  /// ~150, and fills at most 58 % of the screen so two cards are always partly
  /// visible (hinting at horizontal scroll).
  double _productCardWidth(double screenW) =>
      min(220.0, max(150.0, screenW * 0.58));

  // ── Editorial Section ───────────────────────────────────────────────────────

  Widget _buildEditorialSection(double screenW, double hPad) {
    final isSmall = screenW < 400;
    return Container(
      margin: const EdgeInsets.only(top: 64),
      color: AppColors.bg2,
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: CachedNetworkImage(
                  imageUrl:
                      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=80',
                  height: isSmall ? 200 : 280,
                  fit: BoxFit.cover,
                  color: Colors.black38,
                  colorBlendMode: BlendMode.darken,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Dark\nArt of\nTailoring',
                        style: TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: isSmall ? 16 : 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Redefining modern silhouettes through experimental cuts.',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: isSmall ? 10 : 11,
                          color: AppColors.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: screenW * 0.68,
              child: CachedNetworkImage(
                imageUrl:
                    'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=600&q=80',
                height: isSmall ? 150 : 200,
                fit: BoxFit.cover,
                color: Colors.black26,
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter(double hPad) {
    return Container(
      color: AppColors.bg0,
      padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ROCKSTAR',
            style: TextStyle(
              fontFamily: 'Epilogue',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Redefining streetwear. One drop at a time.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Container(
              height: 1, color: AppColors.outlineVariant.withOpacity(0.2)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerLink('SHOP', () => context.go('/search')),
                    _footerLink('WISHLIST', () => context.go('/wishlist')),
                    _footerLink('MY ORDERS', () => context.go('/orders')),
                    _footerLink('PROFILE', () => context.go('/profile')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _footerLink('ABOUT US', null),
                    _footerLink('CONTACT', null),
                    _footerLink('RETURNS', null),
                    _footerLink('PRIVACY POLICY', null),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
              height: 1, color: AppColors.outlineVariant.withOpacity(0.15)),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} Rockstar. All rights reserved.',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              letterSpacing: 1,
              color: AppColors.outline,
            ),
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
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Discover Card ─────────────────────────────────────────────────────────────
// Individual card in the horizontal discover strip.

class _DiscoverCard extends StatelessWidget {
  final Map<String, dynamic> strip;
  final double width;
  final double height;

  const _DiscoverCard({
    required this.strip,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = strip['image_url'] as String? ?? '';
    final title = strip['title'] as String? ?? '';
    final ctaLabel =
        (strip['cta_label'] as String? ?? 'DISCOVER NOW').toUpperCase();
    final actionUrl = strip['action_url'] as String?;

    return GestureDetector(
      onTap: () {
        if (actionUrl != null && actionUrl.isNotEmpty) {
          context.go(actionUrl);
        }
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-bleed image ──────────────────────────────────────────
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.bg2),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.bg2,
                      child: const Icon(Icons.image_outlined,
                          color: Colors.white30, size: 48),
                    ),
                  )
                : Container(color: AppColors.bg2),

            // ── Dark gradient at bottom ───────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.72),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // ── Title + CTA button ────────────────────────────────────────
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Epilogue',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                  ],
                  // CTA button — solid white, black text
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    color: Colors.white,
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product Card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final double width;
  const _ProductCard({required this.product, this.width = 200});

  @override
  Widget build(BuildContext context) {
    final images = product['images'] as List<dynamic>?;
    final imageUrl =
        images != null && images.isNotEmpty ? images[0] as String : null;
    final category = product['categories'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () => context.push('/products/${product['id']}'),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.bg2,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            color: Colors.black12,
                            colorBlendMode: BlendMode.darken,
                          )
                        : const Center(
                            child: Icon(Icons.image_outlined,
                                color: AppColors.outlineVariant, size: 40),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 36,
                      height: 36,
                      color: AppColors.bg0.withOpacity(0.5),
                      child: const Icon(Icons.favorite_outline,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (product['name'] as String).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (category != null)
                        Text(
                          (category['name'] as String).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₹${product['price']}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product Card Skeleton ─────────────────────────────────────────────────────

class _ProductCardSkeleton extends StatelessWidget {
  final double width;
  const _ProductCardSkeleton({this.width = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Container(color: AppColors.bg2)),
          const SizedBox(height: 10),
          Container(width: 120, height: 11, color: AppColors.bg3),
          const SizedBox(height: 6),
          Container(width: 70, height: 9, color: AppColors.bg3),
        ],
      ),
    );
  }
}
