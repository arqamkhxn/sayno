import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../theme/text_styles.dart';

enum SayNOButtonVariant { primary, secondary, danger }

/// Reusable button component.
/// Variants: primary (white fill), secondary (outlined), danger (red fill).
class SayNOButton extends StatelessWidget {
  const SayNOButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = SayNOButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final SayNOButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (variant) {
      SayNOButtonVariant.primary => AppColors.textPrimary,
      SayNOButtonVariant.secondary => AppColors.transparent,
      SayNOButtonVariant.danger => AppColors.danger,
    };

    final foregroundColor = switch (variant) {
      SayNOButtonVariant.primary => AppColors.background,
      SayNOButtonVariant.secondary => AppColors.textPrimary,
      SayNOButtonVariant.danger => AppColors.textPrimary,
    };

    final borderColor = switch (variant) {
      SayNOButtonVariant.primary => AppColors.transparent,
      SayNOButtonVariant.secondary => AppColors.surfaceBorder,
      SayNOButtonVariant.danger => AppColors.transparent,
    };

    final content = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...
                [
                  Icon(icon, size: AppSizes.iconSm, color: foregroundColor),
                  const SizedBox(width: AppSizes.sm),
                ],
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: foregroundColor,
                ),
              ),
            ],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}
