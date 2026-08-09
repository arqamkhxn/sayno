import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/sayno_card.dart';
import '../../../../shared/widgets/sayno_chip.dart';
import '../../../../theme/text_styles.dart';

/// Hero streak card displayed at the top of the dashboard.
class StreakCard extends StatelessWidget {
  const StreakCard({required this.streakDays, super.key});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return SayNOCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SayNOChip(
                  label: AppStrings.disciplineActive,
                  color: AppColors.success,
                  icon: Icons.shield_rounded,
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  '$streakDays',
                  style: AppTextStyles.numericHero.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  AppStrings.streakUnit,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  AppStrings.streakLabel,
                  style: AppTextStyles.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
