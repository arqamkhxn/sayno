import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../theme/text_styles.dart';

/// Section header with optional trailing action.
class SayNOSectionHeader extends StatelessWidget {
  const SayNOSectionHeader({
    required this.title,
    super.key,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleLarge),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
