import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
}

extension ColorExtensions on Color {
  Color withOpacityValue(double opacity) =>
      withValues(alpha: opacity);
}

extension StatusColorExtension on String {
  Color get statusColor {
    switch (toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'danger':
      case 'inactive':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }
}
