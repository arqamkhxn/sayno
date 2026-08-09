import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';

/// A single settings row. Supports toggle, navigation arrow, or value display.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isToggle = false,
    this.toggleValue = false,
    this.onToggleChanged,
    this.titleColor,
    this.showArrow = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final String? trailing;
  final VoidCallback? onTap;
  final bool isToggle;
  final bool toggleValue;
  final ValueChanged<bool>? onToggleChanged;
  final Color? titleColor;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isToggle ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        child: Row(
          children: [
            if (leading != null) ...
              [
                Icon(
                  leading,
                  size: AppSizes.iconMd,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSizes.sm),
              ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...
                    [
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.bodySmall),
                    ],
                ],
              ),
            ),
            if (isToggle)
              Switch(
                value: toggleValue,
                onChanged: onToggleChanged,
              )
            else if (trailing != null) ...
              [
                Text(trailing!, style: AppTextStyles.labelMedium),
                if (showArrow) const SizedBox(width: AppSizes.xs),
              ]
            else if (showArrow)
              const Icon(
                Icons.chevron_right_rounded,
                size: AppSizes.iconMd,
                color: AppColors.textDisabled,
              ),
          ],
        ),
      ),
    );
  }
}
