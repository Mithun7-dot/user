import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    _nameCtrl = TextEditingController(text: meta['full_name'] as String? ?? '');
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': _nameCtrl.text.trim()}),
      );
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('users').update({
          'full_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
        }).eq('id', user.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated',
            style: TextStyle(fontFamily: 'Manrope'))));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e',
            style: const TextStyle(fontFamily: 'Manrope'))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  const Text('EDIT PROFILE',
                    style: TextStyle(fontFamily: 'Epilogue', fontSize: 16,
                      fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 48),
              const Text('PERSONAL DETAILS',
                style: TextStyle(fontFamily: 'Epilogue', fontSize: 22, fontWeight: FontWeight.w900,
                  letterSpacing: -0.3, color: Colors.white)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(labelText: 'FULL NAME'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(labelText: 'PHONE NUMBER'),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2))
                      : const Text('SAVE CHANGES'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
