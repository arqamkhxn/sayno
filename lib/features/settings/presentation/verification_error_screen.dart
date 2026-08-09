import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/release_controller.dart';

class VerificationErrorScreen extends ConsumerWidget {
  const VerificationErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releaseState = ref.watch(releaseControllerProvider);
    final errorMessage = releaseState.errorMessage ?? 'An unknown validation error occurred.';

    // Determine the user-friendly explanation based on the error message text
    String title = 'Security Validation Failed';
    String description = 'A security check failed while trying to authorize deactivation. Protection remains active.';
    IconData errorIcon = Icons.gpp_bad_rounded;
    Color statusColor = AppColors.danger;

    if (errorMessage.contains('NoNetworkException') || errorMessage.toLowerCase().contains('network') || errorMessage.toLowerCase().contains('internet')) {
      title = 'Network Connection Required';
      description = 'An active internet connection is required to fetch and verify secure network time (NTP). Please connect to the internet and try again.';
      errorIcon = Icons.wifi_off_rounded;
      statusColor = AppColors.warning;
    } else if (errorMessage.contains('TimeDriftException') || errorMessage.toLowerCase().contains('drift') || errorMessage.toLowerCase().contains('skew')) {
      title = 'System Time Out of Sync';
      description = 'Your device\'s clock is out of sync with secure network time by 30 seconds or more. Please go to your device settings, enable "Automatic Date & Time", and try again.';
      errorIcon = Icons.update_disabled_rounded;
      statusColor = AppColors.danger;
    } else if (errorMessage.contains('IntegrityCompromisedException') || errorMessage.toLowerCase().contains('integrity') || errorMessage.toLowerCase().contains('manipulation')) {
      title = 'Clock Manipulation Detected';
      description = 'System clock tampering or boot-time clock rollback has been detected. For security purposes, deactivation transitions are locked.';
      errorIcon = Icons.lock_rounded;
      statusColor = AppColors.danger;
    }

    return SayNOScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(AppSizes.xl),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                errorIcon,
                color: statusColor,
                size: 80,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              title,
              style: AppTextStyles.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xxl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.md),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TECHNICAL DETAILS:',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    errorMessage,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xxl),
            SayNOButton(
              label: 'Retry Verification',
              onPressed: () async {
                await ref.read(releaseControllerProvider.notifier).loadActiveRequest();
                if (ref.read(releaseControllerProvider).errorMessage == null) {
                  context.go('/release-cooldown');
                }
              },
            ),
            const SizedBox(height: AppSizes.md),
            SayNOButton(
              label: 'Cancel Request (Re-Lock)',
              variant: SayNOButtonVariant.secondary,
              onPressed: () async {
                await ref.read(releaseControllerProvider.notifier).cancelRelease();
                context.go('/settings');
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
