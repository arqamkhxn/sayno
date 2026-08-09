import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/identity_controller.dart';
import 'identity_flow_provider.dart';

class IdentityReviewScreen extends ConsumerWidget {
  const IdentityReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identities = ref.watch(identityFlowProvider);
    final identityState = ref.watch(identityControllerProvider);

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
            'Review',
            style: AppTextStyles.headlineLarge,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Confirm your configuration.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.xl),

          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: identities.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.xl),
              itemBuilder: (context, index) {
                final identity = identities[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${identity.priority}',
                            style: AppTextStyles.labelSmall.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          identity.profile.label,
                          style: AppTextStyles.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    if (identity.selectedGoals.isEmpty)
                      Text('No specific goals selected.', style: AppTextStyles.bodySmall.copyWith(color: Colors.grey))
                    else
                      Wrap(
                        spacing: AppSizes.sm,
                        runSpacing: AppSizes.sm,
                        children: identity.selectedGoals.map((goal) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBorder,
                              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                            ),
                            child: Text(goal, style: AppTextStyles.labelSmall),
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: identityState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SayNOButton(
                    label: 'Confirm & Save',
                    onPressed: () async {
                      await ref.read(identityControllerProvider.notifier).saveIdentities(identities);
                      if (context.mounted) {
                        context.go('/dashboard');
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
