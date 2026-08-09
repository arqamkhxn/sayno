import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../theme/text_styles.dart';

/// Status chip for displaying labeled states.
/// Color is driven by status type.
class SayNOChip extends StatelessWidget {
  const SayNOChip({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm + 2,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...
            [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 4),
            ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
