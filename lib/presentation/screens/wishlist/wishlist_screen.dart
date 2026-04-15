import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Wishlist provider ────────────────────────────────────────────────────────
final wishlistProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return [];
  final data = await Supabase.instance.client
      .from('wishlist')
      .select('id, product_id, products(id, name, price, images, categories(name))')
      .eq('user_id', session.user.id);
  return List<Map<String, dynamic>>.from(data);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _buildGuestView(context);
    }
    final wishlistAsync = ref.watch(wishlistProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SAVED',
                      style: TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('YOUR WISHLIST',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          letterSpacing: 3,
                          color: AppColors.outline,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: wishlistAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white)),
                error: (e, _) => Center(
                    child: Text('$e',
                        style:
                            const TextStyle(color: Colors.white))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_outline,
                              size: 48,
                              color: AppColors.outlineVariant),
                          const SizedBox(height: 16),
                          Text('NOTHING SAVED YET',
                              style: TextStyle(
                                  fontFamily: 'Epilogue',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.outline)),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () =>
                                context.go('/search'),
                            child: const Text(
                                'EXPLORE COLLECTION'),
                          ),
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
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final product = item['products']
                          as Map<String, dynamic>;
                      return _WishlistCard(
                        wishlistId: item['id'] as String,
                        product: product,
                        onRemoved: () =>
                            ref.invalidate(wishlistProvider),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_outline,
                    size: 64, color: AppColors.outlineVariant),
                const SizedBox(height: 24),
                const Text('YOUR SAVED ITEMS',
                    style: TextStyle(
                        fontFamily: 'Epilogue',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text(
                    'Sign in to view and manage your saved items.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        color: AppColors.outline,
                        height: 1.6)),
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go('/auth/login'),
                      child: const Text('SIGN IN'),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wishlist Card ─────────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  final String wishlistId;
  final Map<String, dynamic> product;
  final VoidCallback onRemoved;

  const _WishlistCard({
    required this.wishlistId,
    required this.product,
    required this.onRemoved,
  });

  Future<void> _remove(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('wishlist')
          .delete()
          .eq('id', wishlistId);
      onRemoved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Removed from wishlist',
                style: TextStyle(fontFamily: 'Manrope'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e',
                style: const TextStyle(fontFamily: 'Manrope'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = product['images'] as List<dynamic>?;
    final imageUrl = images != null && images.isNotEmpty
        ? images[0] as String
        : null;

    return GestureDetector(
      onTap: () => context.push('/products/${product['id']}'),
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
                          width: double.infinity,
                        )
                      : Center(
                          child: Icon(Icons.image_outlined,
                              color: AppColors.outlineVariant,
                              size: 32)),
                ),
                // Remove button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _remove(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      color: Colors.black.withOpacity(0.5),
                      child: const Icon(Icons.favorite,
                          color: Colors.red, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (product['name'] as String).toUpperCase(),
            style: const TextStyle(
                fontFamily: 'Epilogue',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '₹${product['price']}',
            style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ],
      ),
    );
  }
}
