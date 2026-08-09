import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';

/// Quick action buttons row for wallet operations.
class WalletActionRow extends StatelessWidget {
  const WalletActionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _WalletAction(
          icon: Icons.timer_outlined,
          label: 'Borrow',
          onTap: null,
        ),
        _WalletAction(
          icon: Icons.bolt_rounded,
          label: 'Instant',
          onTap: null,
        ),
        _WalletAction(
          icon: Icons.bar_chart_rounded,
          label: 'Analytics',
          onTap: null,
        ),
        _WalletAction(
          icon: Icons.history_rounded,
          label: 'History',
          onTap: null,
        ),
      ],
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.surfaceBorder, width: 1),
            ),
            child: Icon(
              icon,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
