import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Standard card component for SayNO.
/// Dark surface with subtle border. No elevation.
class SayNOCard extends StatelessWidget {
  const SayNOCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: borderColor ?? AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
