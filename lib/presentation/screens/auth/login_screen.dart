import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../infrastructure/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Controllers for the email and password text fields.
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Loading state used to disable the button and show a spinner.
  bool _loading = false;

  // Error message shown when sign-in fails.
  String? _error;

  // Password visibility toggle for the password field.
  bool _obscure = true;

  Future<void> _signIn() async {
    // Do not attempt to sign in when either field is empty.
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;

    // Show loading indicator and clear previous errors.
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Call Supabase auth to sign in with email and password.
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // On success, navigate to the home route.
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      // Capture and display authentication errors.
      setState(() => _error = e.message);
    } finally {
      // Always remove the loading state when the request completes.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBack() {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppConstants.routeSplash);
    }
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is removed to free resources.
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _goBack,
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 48),
              // App branding at the top.
              const Text(
                'ROCKSTAR\nFASHION',
                style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SIGN IN TO CONTINUE',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 64),

              // Email input field.
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  labelText: 'EMAIL ADDRESS',
                  hintText: 'you@example.com',
                ),
              ),
              const SizedBox(height: 32),

              // Password input field with optional visibility toggle.
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  labelText: 'PASSWORD',
                  hintText: '••••••••',
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.outline,
                      size: 18,
                    ),
                  ),
                ),
                onSubmitted: (_) => _signIn(),
              ),

              // Display an error message when login fails.
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: AppColors.error,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],

              const SizedBox(height: 48),
              // Sign-in button, disabled while loading.
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('SIGN IN'),
                ),
              ),
              const SizedBox(height: 24),

              // Link to the registration screen.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'NEW TO ROCKSTAR? ',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: AppColors.outline,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/auth/register'),
                    child: const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        letterSpacing: 2,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
