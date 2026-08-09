import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'component_themes.dart';
import 'text_styles.dart';

/// SayNO application theme.
/// Dark-only. Premium Minimalism.
abstract final class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.textPrimary,
        onPrimary: AppColors.background,
        secondary: AppColors.textSecondary,
        onSecondary: AppColors.background,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        onError: AppColors.textPrimary,
        outline: AppColors.surfaceBorder,
        outlineVariant: AppColors.surfaceElevated,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),
      cardTheme: ComponentThemes.cardTheme(),
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(),
      outlinedButtonTheme: ComponentThemes.outlinedButtonTheme(),
      textButtonTheme: ComponentThemes.textButtonTheme(),
      appBarTheme: ComponentThemes.appBarTheme(),
      navigationBarTheme: ComponentThemes.navigationBarTheme(),
      dividerTheme: ComponentThemes.dividerTheme(),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(),
      switchTheme: ComponentThemes.switchTheme(),
      listTileTheme: ComponentThemes.listTileTheme(),
      splashColor: AppColors.surfaceElevated,
      highlightColor: AppColors.transparent,
      hoverColor: AppColors.surfaceElevated,
    );
  }
}
