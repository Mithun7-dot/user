import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/product/product_detail_screen.dart';
import '../../presentation/screens/cart/cart_screen.dart';
import '../../presentation/screens/wishlist/wishlist_screen.dart';
import '../../presentation/screens/checkout/checkout_screen.dart';
import '../../presentation/screens/orders/orders_screen.dart';
import '../../presentation/screens/orders/order_detail_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/profile/addresses_screen.dart';
import '../../presentation/screens/profile/add_address_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/home/banner_edit_screen.dart';
import '../../presentation/layouts/main_layout.dart';
import '../../core/constants/app_constants.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.routeSplash,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;

      // Auth routes: redirect away if already logged in
      if (loc.startsWith('/auth') && isLoggedIn) return AppConstants.routeHome;

      // Protected routes — require authentication
      final protectedPrefixes = ['/checkout', '/profile/edit', '/orders'];
      final isProtected = protectedPrefixes.any((p) => loc.startsWith(p));
      if (isProtected && !isLoggedIn) return AppConstants.routeLogin;

      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      // Shell route for bottom nav
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeHome,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.routeCart,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CartScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.routeWishlist,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WishlistScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.routeOrders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrdersScreen(),
            ),
          ),
          GoRoute(
            path: AppConstants.routeProfile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppConstants.routeProducts,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: SearchScreen(
            initialCategoryId: state.uri.queryParameters['categoryId'],
          ),
        ),
      ),
      GoRoute(
        path: AppConstants.routeSearch,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: SearchScreen(
            initialCategoryId: state.uri.queryParameters['categoryId'],
          ),
        ),
      ),

      GoRoute(
        path: '/products/:id',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppConstants.routeCheckout,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const CheckoutScreen(),
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: OrderDetailScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppConstants.routeEditProfile,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeAddresses,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const AddressesScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeAddAddress,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: const AddAddressScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeBannerEdit,
        pageBuilder: (context, state) => _slideTransition(
          state: state,
          child: AdminOnlyRoute(
            child: BannerEditScreen(
              bannerId: state.pathParameters['id']!,
            ),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Page not found',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
});

CustomTransitionPage _slideTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class AdminOnlyRoute extends StatefulWidget {
  final Widget child;
  const AdminOnlyRoute({super.key, required this.child});

  @override
  State<AdminOnlyRoute> createState() => _AdminOnlyRouteState();
}

class _AdminOnlyRouteState extends State<AdminOnlyRoute> {
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _loading = false;
          });
        }
        return;
      }

      final metadata = user.userMetadata;
      final String? role = metadata?['role'];

      if (role == 'admin') {
        if (mounted) {
          setState(() {
            _isAdmin = true;
            _loading = false;
          });
        }
      } else {
        try {
          final data = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

          if (mounted) {
            setState(() {
              _isAdmin = (data?['role'] as String?) == 'admin';
              _loading = false;
            });
          }
        } catch (dbError) {
          if (mounted) {
            setState(() {
              _isAdmin = false;
              _loading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: const Text('Access denied'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Administrator access is required to edit banners.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppConstants.routeHome),
                  child: const Text('RETURN TO HOME'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
