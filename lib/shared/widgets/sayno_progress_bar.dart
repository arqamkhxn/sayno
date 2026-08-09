import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Animated progress bar with status-aware coloring.
class SayNOProgressBar extends StatelessWidget {
  const SayNOProgressBar({
    required this.value,
    super.key,
    this.color,
    this.height = 6.0,
    this.backgroundColor,
  }) : assert(value >= 0.0 && value <= 1.0, 'value must be between 0.0 and 1.0');

  final double value;
  final Color? color;
  final double height;
  final Color? backgroundColor;

  Color _resolveColor() {
    if (color != null) return color!;
    if (value >= 0.85) return AppColors.danger;
    if (value >= 0.65) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: backgroundColor ?? AppColors.surfaceElevated,
        valueColor: AlwaysStoppedAnimation<Color>(_resolveColor()),
      ),
    );
  }
}
