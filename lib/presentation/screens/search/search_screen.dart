import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchCategoryProvider = StateProvider<String?>((ref) => null);

// Fetch all active categories for filter chips
final searchCategoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('categories')
      .select('id, name')
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(data);
});

typedef SearchParams = ({String search, String? categoryId});

final searchProductsProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    SearchParams>((ref, params) async {
  var query = Supabase.instance.client
      .from('products')
      .select('*, categories(name)')
      .eq('is_active', true);

  final search = params.search;
  if (search.isNotEmpty) {
    query = query.ilike('name', '%$search%');
  }

  final categoryId = params.categoryId;
  if (categoryId != null && categoryId.isNotEmpty) {
    query = query.eq('category_id', categoryId);
  }

  final data =
      await query.order('created_at', ascending: false).limit(40);
  return List<Map<String, dynamic>>.from(data);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  const SearchScreen({super.key, this.initialCategoryId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategoryId; // null = ALL

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _onSearchSubmitted(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final params = (
      search: _query,
      categoryId: _selectedCategoryId,
    );
    final productsAsync = ref.watch(searchProductsProvider(params));
    final categoriesAsync = ref.watch(searchCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: false,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          color: Colors.white,
                          fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'SEARCH COLLECTION...',
                        hintStyle: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            letterSpacing: 2,
                            color: AppColors.outline),
                        border: const UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.outlineVariant)),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.outlineVariant)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.white)),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: Icon(Icons.search,
                            color: AppColors.outline, size: 20),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                    ),
                  ),
                ],
              ),
            ),
            // ── Category Filter Chips (from DB) ────────────────────────────
            SizedBox(
              height: 44,
              child: categoriesAsync.when(
                loading: () => const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 1.5))),
                error: (_, __) => const SizedBox(),
                data: (cats) {
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: cats.length + 1, // +1 for ALL chip
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        // ALL chip
                        final selected =
                            _selectedCategoryId == null;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _selectedCategoryId = null),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            color: selected
                                ? Colors.white
                                : AppColors.bg4,
                            child: Text('ALL',
                                style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                    color: selected
                                        ? AppColors.onPrimary
                                        : AppColors.secondary)),
                          ),
                        );
                      }
                      final cat = cats[i - 1];
                      final catId = cat['id'] as String;
                      final selected = _selectedCategoryId == catId;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _selectedCategoryId =
                                selected ? null : catId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          color:
                              selected ? Colors.white : AppColors.bg4,
                          child: Text(
                              (cat['name'] as String).toUpperCase(),
                              style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: selected
                                      ? AppColors.onPrimary
                                      : AppColors.secondary)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // ── Product Grid ───────────────────────────────────────────────
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white)),
                error: (e, _) => Center(
                    child: Text('$e',
                        style: const TextStyle(color: Colors.white))),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('NO RESULTS FOUND',
                              style: TextStyle(
                                  fontFamily: 'Epilogue',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.outline)),
                          const SizedBox(height: 8),
                          Text(
                              _query.isEmpty
                                  ? 'No products in this category yet.'
                                  : 'Try a different search term.',
                              style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  color: AppColors.outlineVariant)),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(24, 8, 24, 120),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 24,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) =>
                        _GridProductCard(product: products[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid Product Card ─────────────────────────────────────────────────────────

class _GridProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _GridProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final images = product['images'] as List<dynamic>?;
    final imageUrl = images != null && images.isNotEmpty
        ? images[0] as String
        : null;
    final category = product['categories'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () => context.push('/products/${product['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: AppColors.bg2,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity)
                  : Center(
                      child: Icon(Icons.image_outlined,
                          color: AppColors.outlineVariant, size: 32)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            (product['name'] as String).toUpperCase(),
            style: const TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (category != null)
                Text((category['name'] as String).toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700)),
              Text('₹${product['price']}',
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
