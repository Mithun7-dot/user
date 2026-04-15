import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/theme/app_theme.dart';

// Provider that returns cart item count (0 if not logged in)
final cartCountProvider = FutureProvider<int>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return 0;
  final data = await Supabase.instance.client
      .from('cart')
      .select('id')
      .eq('user_id', session.user.id);
  return (data as List).length;
});

class MainLayout extends ConsumerWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  static int _locationToIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/products') || location.startsWith('/search')) return 1;
    if (location.startsWith('/wishlist')) return 2;
    if (location.startsWith('/cart')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);
    final cartCountAsync = ref.watch(cartCountProvider);
    final cartCount = cartCountAsync.valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      extendBody: true,
      bottomNavigationBar: _ObsidianNavBar(
        currentIndex: currentIndex,
        cartCount: cartCount,
      ),
    );
  }
}

class _ObsidianNavBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  const _ObsidianNavBar({required this.currentIndex, required this.cartCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: AppColors.bg4.withOpacity(0.6),
        border: const Border(
          top: BorderSide(color: Color(0x08FFFFFF), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ColorFilter.mode(
            AppColors.bg4.withOpacity(0.6),
            BlendMode.srcOver,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  iconFilled: Icons.home,
                  label: 'HOME',
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: () => context.go('/home'),
                ),
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  iconFilled: Icons.grid_view,
                  label: 'SHOP',
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: () => context.go('/search'),
                ),
                _NavItem(
                  icon: Icons.favorite_outline,
                  iconFilled: Icons.favorite,
                  label: 'SAVED',
                  index: 2,
                  currentIndex: currentIndex,
                  onTap: () => context.go('/wishlist'),
                ),
                _NavItem(
                  icon: Icons.shopping_bag_outlined,
                  iconFilled: Icons.shopping_bag,
                  label: 'BAG',
                  index: 3,
                  currentIndex: currentIndex,
                  onTap: () => context.go('/cart'),
                  badgeCount: cartCount,
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  iconFilled: Icons.person,
                  label: 'YOU',
                  index: 4,
                  currentIndex: currentIndex,
                  onTap: () => context.go('/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.iconFilled,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(top: BorderSide(color: Colors.white, width: 2))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? iconFilled : icon,
                  color: isActive ? Colors.white : const Color(0xFF888888),
                  size: 22,
                ),
                // Only show badge dot when cart has items
                if (badgeCount > 0)
                  Positioned(
                    top: -3,
                    right: -5,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isActive ? Colors.white : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
