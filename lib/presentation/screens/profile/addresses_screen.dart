import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../infrastructure/theme/app_theme.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final addressesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return [];

  final data = await Supabase.instance.client
      .from('addresses')
      .select()
      .eq('user_id', session.user.id)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(data);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  const Text('ADDRESS MANAGEMENT',
                      style: TextStyle(
                          fontFamily: 'Epilogue',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                ],
              ),
            ),

            // Content
            Expanded(
              child: addressesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
                error: (e, _) => Center(
                    child: Text('$e',
                        style: const TextStyle(color: Colors.white))),
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return _buildAddressesList(context, ref, addresses);
                },
              ),
            ),

            // Add Address Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.push(AppConstants.routeAddAddress),
                  child: const Text('ADD NEW ADDRESS'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppColors.outlineVariant, size: 64),
            const SizedBox(height: 24),
            const Text('NO ADDRESSES YET',
                style: TextStyle(
                    fontFamily: 'Epilogue',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            const Text('Add your delivery addresses for faster checkout',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: AppColors.outline,
                    height: 1.6)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => context.push(AppConstants.routeAddAddress),
                child: const Text('ADD YOUR FIRST ADDRESS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesList(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> addresses) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        return _AddressCard(
          address: address,
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.bg2,
                title: const Text('Delete Address',
                    style: TextStyle(color: Colors.white)),
                content: const Text(
                    'Are you sure you want to delete this address?',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('DELETE'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await Supabase.instance.client
                  .from('addresses')
                  .delete()
                  .eq('id', address['id']);
              ref.invalidate(addressesProvider);
            }
          },
        );
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onDelete;

  const _AddressCard({required this.address, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDefault = address['is_default'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border.all(
            color: isDefault ? AppColors.onPrimary : AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DEFAULT',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary,
                          letterSpacing: 1)),
                ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(address['full_name'] as String,
              style: const TextStyle(
                  fontFamily: 'Epilogue',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(
              '${address['line_1']}${address['line_2'] != null ? ', ${address['line_2']}' : ''}',
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4)),
          Text('${address['city']}, ${address['state']} ${address['pincode']}',
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4)),
          const SizedBox(height: 4),
          Text(address['phone'] as String,
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
