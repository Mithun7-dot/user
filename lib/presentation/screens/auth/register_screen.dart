import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        data: {'full_name': _nameCtrl.text.trim()},
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
              const SizedBox(height: 64),
              GestureDetector(
                onTap: () => context.go('/auth/login'),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 40),
              const Text(
                'JOIN THE\nGALLERY',
                style: TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'CREATE YOUR ACCOUNT',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 56),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                    fontFamily: 'Manrope', color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                    labelText: 'FULL NAME', hintText: 'Your Name'),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                    fontFamily: 'Manrope', color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                    labelText: 'EMAIL ADDRESS', hintText: 'you@example.com'),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(
                    fontFamily: 'Manrope', color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'PASSWORD',
                  hintText: 'Min 6 characters',
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
                onSubmitted: (_) => _register(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: AppColors.error,
                        fontSize: 12)),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.onPrimary, strokeWidth: 2))
                      : const Text('CREATE ACCOUNT'),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ALREADY HAVE AN ACCOUNT? ',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          letterSpacing: 2,
                          color: AppColors.outline)),
                  GestureDetector(
                    onTap: () => context.go('/auth/login'),
                    child: const Text('SIGN IN',
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white)),
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
