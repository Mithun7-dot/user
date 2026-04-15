import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../infrastructure/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _letterController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _letterController,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 1.04, end: 1.0).animate(
      CurvedAnimation(parent: _letterController, curve: Curves.easeOut),
    );

    _letterController.forward();
    Future.delayed(const Duration(milliseconds: 2400), () {
      _fadeController.forward().then((_) {
        if (mounted) context.go('/home');
      });
    });
  }

  @override
  void dispose() {
    _letterController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_fadeController),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ROCKSTAR',
                    style: TextStyle(
                      fontFamily: 'Epilogue',
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    'Fashion',
                    style: TextStyle(
                      fontFamily: 'Epilogue',
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 40,
                    height: 1,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'THE The premium GALLERY',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
