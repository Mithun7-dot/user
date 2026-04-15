class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'https://dpvvgioytyfhigrnsdyo.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwdnZnaW95dHlmaGlncm5zZHlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3MDcyNTMsImV4cCI6MjA5MTI4MzI1M30.8afzf1dR2D-knqnqPzLqbn4cION9g2cO4Oag3aKCV9M';

  // Razorpay (Sandbox Test Keys)
  static const String razorpayKeyId = 'MDgOGWE7dvjzxonsWBkhMOXi';
  static const String appName = 'Rockstar';
  static const String appCurrency = 'INR';
  static const String appCurrencySymbol = '₹';

  // App Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/auth/login';
  static const String routeRegister = '/auth/register';
  static const String routeHome = '/home';
  static const String routeProducts = '/products';
  static const String routeProductDetail = '/products/:id';
  static const String routeCart = '/cart';
  static const String routeWishlist = '/wishlist';
  static const String routeCheckout = '/checkout';
  static const String routeOrderSuccess = '/order-success';
  static const String routeOrders = '/orders';
  static const String routeOrderDetail = '/orders/:id';
  static const String routeProfile = '/profile';
  static const String routeEditProfile = '/profile/edit';
  static const String routeAddresses = '/profile/addresses';
  static const String routeAddAddress = '/profile/addresses/add';
  static const String routeBannerEdit = '/admin/banners/edit/:id';

  static String routeBannerEditFor(String bannerId) =>
      routeBannerEdit.replaceFirst(':id', bannerId);

  static const String routeSearch = '/search';

  // Default Values
  static const double shippingFee = 49.0;
  static const double freeShippingThreshold = 999.0;
  static const int maxCartQuantity = 10;
}
