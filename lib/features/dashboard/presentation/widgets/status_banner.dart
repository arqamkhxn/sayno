import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/sayno_chip.dart';
import '../../../../theme/text_styles.dart';
import '../../../protection/domain/protection_status.dart';

/// Full-width status banner indicating protection state.
class StatusBanner extends StatelessWidget {
  const StatusBanner({required this.status, super.key});

  final ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProtectionStatus.protected => AppColors.success,
      ProtectionStatus.protectionRequired => AppColors.warning,
      ProtectionStatus.unknown => AppColors.textSecondary,
    };
    final icon = switch (status) {
      ProtectionStatus.protected => Icons.shield_rounded,
      ProtectionStatus.protectionRequired => Icons.shield_outlined,
      ProtectionStatus.unknown => Icons.shield_outlined,
    };
    final message = switch (status) {
      ProtectionStatus.protected => 'Accessibility protection is enabled.',
      ProtectionStatus.protectionRequired => 'Enable Accessibility Service.',
      ProtectionStatus.unknown => 'Reading protection status.',
    };
    final chipLabel = switch (status) {
      ProtectionStatus.protected => 'ON',
      ProtectionStatus.protectionRequired => 'OFF',
      ProtectionStatus.unknown => '...',
    };

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.displayLabel,
                  style: AppTextStyles.titleMedium.copyWith(color: color),
                ),
                Text(message, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          SayNOChip(
            label: chipLabel,
            color: color,
          ),
        ],
      ),
    );
  }
}
