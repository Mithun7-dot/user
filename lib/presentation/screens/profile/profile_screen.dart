import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Live stats providers ─────────────────────────────────────────────────────

final profileOrderCountProvider = FutureProvider<int>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return 0;
  final data = await Supabase.instance.client
      .from('orders')
      .select('id')
      .eq('user_id', session.user.id);
  return (data as List).length;
});

final profileWishlistCountProvider = FutureProvider<int>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return 0;
  final data = await Supabase.instance.client
      .from('wishlist')
      .select('id')
      .eq('user_id', session.user.id);
  return (data as List).length;
});

final profileCreditsProvider = FutureProvider<num>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return 0;
  final data = await Supabase.instance.client
      .from('users')
      .select('credits')
      .eq('id', session.user.id)
      .maybeSingle();
  return data?['credits'] as num? ?? 0;
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _buildGuestProfile(context);
    }
    return _buildProfile(context, ref, user);
  }

  Widget _buildGuestProfile(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _appBar(context),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.person_outline,
                      size: 64, color: AppColors.outlineVariant),
                  const SizedBox(height: 24),
                  const Text('JOIN THE GALLERY',
                      style: TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  const Text(
                      'Sign in to view your profile, orders, and wishlist.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          color: AppColors.outline,
                          height: 1.6)),
                  const SizedBox(height: 40),
                  SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => context.go('/auth/login'),
                        child: const Text('SIGN IN'),
                      )),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => context.go('/auth/register'),
                        child: const Text('CREATE ACCOUNT'),
                      )),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, dynamic user) {
    final email = user.email as String? ?? '';
    final meta = user.userMetadata as Map<String, dynamic>? ?? {};
    final name = meta['full_name'] as String? ?? email.split('@')[0];
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final orderCount = ref.watch(profileOrderCountProvider);
    final wishlistCount = ref.watch(profileWishlistCountProvider);
    final credits = ref.watch(profileCreditsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _appBar(context),
              ),
            ),
          ),
          // Avatar + Name
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.outlineVariant, width: 1),
                          color: AppColors.bg4,
                        ),
                        child: Center(
                          child: Text(initials,
                              style: const TextStyle(
                                  fontFamily: 'Epilogue',
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Container(
                            width: 32,
                            height: 32,
                            color: Colors.white,
                            child: const Icon(Icons.edit,
                                color: AppColors.onPrimary, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(name.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('ELITE MEMBER',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          letterSpacing: 3,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          // Stats Bento — live data
          SliverToBoxAdapter(
            child: _buildStats(context, orderCount, credits, wishlistCount),
          ),
          // Menu
          SliverToBoxAdapter(child: _buildMenu(context, email)),
          // Editorial Promo
          SliverToBoxAdapter(child: _buildPromo()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('ROCKSTAR',
            style: TextStyle(
                fontFamily: 'Epilogue',
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontSize: 14,
                color: Colors.white)),
      ],
    );
  }

  Widget _buildStats(
    BuildContext context,
    AsyncValue<int> orderCount,
    AsyncValue<num> credits,
    AsyncValue<int> wishlistCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF444444)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/orders'),
              child: _StatCell(
                label: 'ORDERS',
                value: orderCount.when(
                    data: (v) => '$v',
                    loading: () => '—',
                    error: (_, __) => '0'),
              ),
            ),
          ),
          Container(width: 1, height: 80, color: const Color(0xFF444444)),
          Expanded(
            child: _StatCell(
              label: 'CREDITS',
              value: credits.when(
                  data: (v) => v.toStringAsFixed(0),
                  loading: () => '—',
                  error: (_, __) => '0'),
            ),
          ),
          Container(width: 1, height: 80, color: const Color(0xFF444444)),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/wishlist'),
              child: _StatCell(
                label: 'WISHLIST',
                value: wishlistCount.when(
                    data: (v) => '$v',
                    loading: () => '—',
                    error: (_, __) => '0'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context, String email) {
    final items = [
      {
        'icon': Icons.inventory_2_outlined,
        'label': 'MY ORDERS',
        'route': '/orders'
      },
      {
        'icon': Icons.favorite_outline,
        'label': 'MY WISHLIST',
        'route': '/wishlist'
      },
      {
        'icon': Icons.location_on_outlined,
        'label': 'ADDRESS MANAGEMENT',
        'route': AppConstants.routeAddresses
      },
      {
        'icon': Icons.payment_outlined,
        'label': 'PAYMENT METHODS',
        'route': null
      },
      {'icon': Icons.settings_outlined, 'label': 'SETTINGS', 'route': null},
      {'icon': Icons.help_outline, 'label': 'HELP CENTER', 'route': null},
    ];

    return Column(
      children: [
        const SizedBox(height: 32),
        ...items.map((item) => GestureDetector(
              onTap: () {
                if (item['route'] != null) {
                  context.push(item['route'] as String);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF444444))),
                ),
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData,
                        color: AppColors.secondary, size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(item['label'] as String,
                          style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.white)),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.outline, size: 20),
                  ],
                ),
              ),
            )),
        // Logout
        GestureDetector(
          onTap: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/home');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: const Text('LOGOUT',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    letterSpacing: 4,
                    color: AppColors.error,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildPromo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      color: AppColors.bg4,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('THE ROCKSTAR INNER CIRCLE',
              style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.2)),
          const SizedBox(height: 8),
          const Text('Early access to limited drops and private events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: AppColors.secondary,
                  height: 1.6)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('JOIN INNER CIRCLE'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 9,
                  letterSpacing: 2,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
