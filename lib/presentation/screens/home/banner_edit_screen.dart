import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../infrastructure/theme/app_theme.dart';

class BannerEditScreen extends ConsumerStatefulWidget {
  final String bannerId;
  const BannerEditScreen({super.key, required this.bannerId});

  @override
  ConsumerState<BannerEditScreen> createState() => _BannerEditScreenState();
}

class _BannerEditScreenState extends ConsumerState<BannerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _ctaCtrl = TextEditingController();
  final _actionUrlCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  bool _isActive = true;
  bool _isEditable = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBanner();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _ctaCtrl.dispose();
    _actionUrlCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    try {
      final data = await Supabase.instance.client
          .from('banners')
          .select()
          .eq('id', widget.bannerId)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = 'Banner not found.';
          _loading = false;
        });
        return;
      }

      _titleCtrl.text = data['title'] as String? ?? '';
      _subtitleCtrl.text = data['subtitle'] as String? ?? '';
      _ctaCtrl.text = data['cta_label'] as String? ?? '';
      _actionUrlCtrl.text = data['action_url'] as String? ?? '';
      _imageUrlCtrl.text = data['image_url'] as String? ?? '';
      _isActive = data['is_active'] as bool? ?? true;
      _isEditable = data['is_editable'] as bool? ?? false;
      _selectedCategoryId = _parseCategoryId(_actionUrlCtrl.text);

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Unable to load banner: $e');
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      // ignore category load failure for now
    }
  }

  String? _parseCategoryId(String actionUrl) {
    final uri = Uri.tryParse(actionUrl);
    if (uri == null) return null;
    return uri.queryParameters['categoryId'];
  }

  Future<void> _saveBanner() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditable) return;

    setState(() => _saving = true);

    final actionUrl = _selectedCategoryId != null
        ? '/search?categoryId=${_selectedCategoryId!}'
        : '';

    try {
      await Supabase.instance.client.from('banners').update({
        'title': _titleCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
        'cta_label': _ctaCtrl.text.trim(),
        'action_url': actionUrl,
        'image_url': _imageUrlCtrl.text.trim(),
        'is_active': _isActive,
      }).eq('id', widget.bannerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Banner updated successfully.'),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error saving banner: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Banner Editor'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)))
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isEditable) ...[
                              const Text(
                                'Read-only banner',
                                style: TextStyle(
                                    color: AppColors.secondary,
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildField(_titleCtrl, 'Banner Title'),
                            const SizedBox(height: 18),
                            _buildField(_subtitleCtrl, 'Banner Subtitle'),
                            const SizedBox(height: 18),
                            _buildField(_ctaCtrl, 'CTA Label'),
                            const SizedBox(height: 18),
                            _buildCategorySelector(),
                            const SizedBox(height: 18),
                            _buildField(_imageUrlCtrl, 'Image URL',
                                hint: 'https://...'),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Text('Active',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Manrope')),
                                const Spacer(),
                                Switch(
                                  value: _isActive,
                                  onChanged: _isEditable
                                      ? (value) =>
                                          setState(() => _isActive = value)
                                      : null,
                                  activeThumbColor: AppColors.onPrimary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isEditable && !_saving
                                    ? _saveBanner
                                    : null,
                                child: _saving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text('SAVE BANNER'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Target Category',
        labelStyle: TextStyle(
            color: AppColors.outline,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategoryId,
          isExpanded: true,
          iconEnabledColor: Colors.white,
          dropdownColor: AppColors.background,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          hint: const Text('Select a category',
              style: TextStyle(color: AppColors.outlineVariant)),
          items: _categories.map((category) {
            return DropdownMenuItem<String>(
              value: category['id'] as String,
              child: Text(category['name'] as String),
            );
          }).toList(),
          onChanged: _isEditable
              ? (value) => setState(() => _selectedCategoryId = value)
              : null,
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {String? hint}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
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
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      validator: (value) {
        if (ctrl == _titleCtrl && (value?.trim().isEmpty ?? true)) {
          return 'Banner title is required';
        }
        return null;
      },
    );
  }
}
