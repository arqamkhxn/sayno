import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';

/// A global banner displayed when the user is in Guest Mode.
class GuestLoginBanner extends StatelessWidget {
  const GuestLoginBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'You are in Guest Mode. Log in or Sign Up to sync your progress.',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            GestureDetector(
              onTap: () => context.push('/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Text(
                  'Log In',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
