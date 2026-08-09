import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';

/// A labeled group of settings tiles.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textDisabled,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.surfaceBorder, width: 1),
          ),
          child: Column(
            children: children.indexed.map((entry) {
              final index = entry.$1;
              final child = entry.$2;
              final isLast = index == children.length - 1;
              return Column(
                children: [
                  child,
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: AppSizes.md,
                      endIndent: AppSizes.md,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
