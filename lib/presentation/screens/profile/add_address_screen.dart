import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';
import 'addresses_screen.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please sign in to save addresses.',
                  style: TextStyle(fontFamily: 'Manrope'))));
        }
        return;
      }

      // If setting as default, unset other defaults first
      if (_isDefault) {
        await Supabase.instance.client
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', session.user.id)
            .eq('is_default', true);
      }

      await Supabase.instance.client
          .from('addresses')
          .insert({
            'user_id': session.user.id,
            'full_name': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'line_1': _line1Ctrl.text.trim(),
            'line_2':
                _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
            'city': _cityCtrl.text.trim(),
            'state': _stateCtrl.text.trim(),
            'pincode': _pincodeCtrl.text.trim(),
            'is_default': _isDefault,
          })
          .select()
          .single();

      if (mounted) {
        ref.invalidate(addressesProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Address saved successfully.',
                style: TextStyle(fontFamily: 'Manrope'))));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving address: $e',
                style: const TextStyle(fontFamily: 'Manrope'))));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text('ADD ADDRESS',
                        style: TextStyle(
                            fontFamily: 'Epilogue',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Colors.white)),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(_nameCtrl, 'FULL NAME', 'Your Name',
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? 'Required'
                              : null),
                      const SizedBox(height: 24),
                      _buildField(_phoneCtrl, 'PHONE NUMBER', '00000 00000',
                          type: TextInputType.phone, validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Required';
                        }
                        if ((value?.length ?? 0) < 10) {
                          return 'Invalid phone number';
                        }
                        return null;
                      }),
                      const SizedBox(height: 24),
                      _buildField(_line1Ctrl, 'ADDRESS LINE 1',
                          'Street, Building, Area',
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? 'Required'
                              : null),
                      const SizedBox(height: 24),
                      _buildField(_line2Ctrl, 'ADDRESS LINE 2',
                          'Apartment, Floor (Optional)'),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                              child: _buildField(_cityCtrl, 'CITY', 'City',
                                  validator: (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildField(_stateCtrl, 'STATE', 'State',
                                  validator: (value) =>
                                      value?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildField(_pincodeCtrl, 'PINCODE', '000000',
                          type: TextInputType.number, validator: (value) {
                        if (value?.trim().isEmpty ?? true) return 'Required';
                        if ((value?.length ?? 0) != 6) return 'Invalid pincode';
                        return null;
                      }),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Checkbox(
                            value: _isDefault,
                            onChanged: (value) =>
                                setState(() => _isDefault = value ?? false),
                            activeColor: AppColors.onPrimary,
                          ),
                          const SizedBox(width: 12),
                          const Text('SET AS DEFAULT ADDRESS',
                              style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Save Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.onPrimary)
                        : const Text('SAVE ADDRESS'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, String hint,
      {TextInputType type = TextInputType.text,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: AppColors.outline,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700),
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.outlineVariant, fontSize: 13),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlineVariant)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
        errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error)),
      ),
      validator: validator,
    );
  }
}
