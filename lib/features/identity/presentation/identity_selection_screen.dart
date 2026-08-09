import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/identity_catalog_controller.dart';
import '../domain/identity_profile.dart';
import '../domain/user_identity.dart';
import 'identity_flow_provider.dart';

class IdentitySelectionScreen extends ConsumerStatefulWidget {
  const IdentitySelectionScreen({super.key});

  @override
  ConsumerState<IdentitySelectionScreen> createState() => _IdentitySelectionScreenState();
}

class _IdentitySelectionScreenState extends ConsumerState<IdentitySelectionScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelection(IdentityProfile profile) {
    setState(() {
      if (_selectedIds.contains(profile.id)) {
        _selectedIds.remove(profile.id);
      } else {
        if (_selectedIds.length < 4) {
          _selectedIds.add(profile.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can select up to 4 identities.')),
          );
        }
      }
    });
  }

  void _onNext(List<IdentityProfile> profiles) {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 identity.')),
      );
      return;
    }

    final selectedProfiles = profiles.where((p) => _selectedIds.contains(p.id)).toList();
    
    // Map to UserIdentity
    final userIdentities = selectedProfiles.asMap().entries.map((entry) {
      return UserIdentity(
        profile: entry.value,
        priority: entry.key + 1,
        selectedGoals: [],
      );
    }).toList();

    ref.read(identityFlowProvider.notifier).state = userIdentities;
    context.push('/identity/priority');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('UI: IdentitySelectionScreen build() called');
    final catalogAsync = ref.watch(identityCatalogControllerProvider);

    return SayNOScaffold(
      scrollable: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Who are you?',
            style: AppTextStyles.headlineLarge,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Select up to 4 identities.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.xl),

          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading identities: $e')),
              data: (profiles) {
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isSelected = _selectedIds.contains(profile.id);

                    return InkWell(
                      onTap: () => _toggleSelection(profile),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent.withOpacity(0.2) : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                          border: Border.all(
                            color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Using standard icons based on iconName for now
                            Icon(Icons.person, color: isSelected ? AppColors.accent : Colors.white),
                            const SizedBox(width: AppSizes.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.label,
                                    style: AppTextStyles.titleMedium,
                                  ),
                                  Text(
                                    profile.description,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: AppColors.accent),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: catalogAsync.maybeWhen(
              data: (profiles) => SayNOButton(
                label: 'Continue',
                onPressed: () => _onNext(profiles),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
