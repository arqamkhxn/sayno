import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../theme/text_styles.dart';

/// A compact stat display tile: label on top, value below.
class SayNOStatTile extends StatelessWidget {
  const SayNOStatTile({
    required this.label,
    required this.value,
    super.key,
    this.valueColor,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...
              [
                Icon(icon, size: AppSizes.iconSm, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.xs),
              ],
            Text(label, style: AppTextStyles.labelMedium),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          value,
          style: AppTextStyles.headlineSmall.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...
          [
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
      ],
    );
  }
}
