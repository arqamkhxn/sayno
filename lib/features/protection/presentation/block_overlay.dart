import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../theme/text_styles.dart';
import '../application/block_overlay_controller.dart';
import '../application/app_detection_controller.dart';
import '../domain/block_reason.dart';
import '../../contract/application/contract_controller.dart';
import '../../contract/domain/contract.dart';
import '../../contract/domain/contract_app.dart';
import '../../protection/domain/monitored_apps.dart';

/// A full-screen block overlay UI.
/// Appears on top of the entire application hierarchy when triggered by
/// keyword detection, limit reaching, or commitment violations.
class BlockOverlay extends ConsumerWidget {
  const BlockOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(isBlockOverlayVisibleProvider);
    final reason = ref.watch(blockReasonProvider);

    if (!isVisible || reason == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(blockOverlayProvider.notifier);
    final activePackage = ref.watch(activePackageProvider);
    final activeContractAsync = ref.watch(activeContractProvider);

    ContractApp? contractApp;
    final activeContract = activeContractAsync.value;
    if (activeContract != null && activePackage != null) {
      for (final app in activeContract.apps) {
        if (app.packageName == activePackage) {
          contractApp = app;
          break;
        }
      }
    }

    final appLabel = activePackage != null
        ? (monitoredAppsRegistry[activePackage] ?? activePackage.split('.').last)
        : '';

    // Decide what to display
    String titleText = reason.title;
    String messageText = reason.message;
    bool showBorrow = false;
    bool noCreditsRemaining = false;

    if (reason == BlockReason.dailyLimitReached && contractApp != null) {
      if (contractApp.remainingCredits.inSeconds <= 0) {
        noCreditsRemaining = true;
        titleText = 'No Credits Remaining';
        messageText = 'You have depleted your credit pool for $appLabel. Access remains blocked for the rest of the contract duration.';
      } else {
        showBorrow = true;
        titleText = 'Limit Reached';
        messageText = 'You have reached your daily limit for $appLabel. Exceeding daily limits resets your streak unless you borrow credits.';
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Swallows all taps to prevent background interactions
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
              vertical: AppSizes.lg,
            ),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Icon
                Icon(
                  noCreditsRemaining
                      ? Icons.error_outline_rounded
                      : Icons.lock_outline_rounded,
                  size: AppSizes.iconXl * 2, // 64
                  color: noCreditsRemaining ? AppColors.danger : AppColors.textSecondary,
                ),
                const SizedBox(height: AppSizes.lg),
                // Title text
                Text(
                  titleText,
                  style: AppTextStyles.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.sm),
                // Message text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: Text(
                    messageText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(flex: 4),
                // Actions list
                Column(
                  children: [
                    if (showBorrow && activeContract != null && contractApp != null) ...[
                      SayNOButton(
                        label: 'Borrow Minutes',
                        onPressed: () => _showBorrowDialog(context, ref, activeContract, contractApp!),
                      ),
                      const SizedBox(height: AppSizes.md),
                    ] else if (noCreditsRemaining) ...[
                      // Disabled placeholder Top-Up Credits button
                      SayNOButton(
                        label: 'Top-Up Credits (Coming Soon)',
                        variant: SayNOButtonVariant.secondary,
                        onPressed: null, // Disabled
                      ),
                      const SizedBox(height: AppSizes.md),
                    ],
                    SayNOButton(
                      label: 'Go Back',
                      onPressed: notifier.handleGoBack,
                    ),
                    const SizedBox(height: AppSizes.md),
                    SayNOButton(
                      label: 'Close',
                      variant: SayNOButtonVariant.secondary,
                      onPressed: notifier.handleClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBorrowDialog(
    BuildContext context,
    WidgetRef ref,
    Contract contract,
    ContractApp app,
  ) {
    final appLabel = monitoredAppsRegistry[app.packageName] ?? app.packageName.split('.').last;
    final maxBorrow = min(60, app.remainingCredits.inMinutes);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        double selectedBorrow = min(15, maxBorrow).toDouble();
        if (selectedBorrow < 1) selectedBorrow = maxBorrow.toDouble();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: Violation',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Borrowing minutes is a contract violation that will penalize your progress:',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _buildBulletPoint('Reset streak to 0 (Current: ${contract.currentStreak} days)'),
                  _buildBulletPoint('Mark today as a Failed Day (Red Day)'),
                  _buildBulletPoint('Deduct minutes from pool (Remaining: ${app.remainingCredits.inMinutes}m)'),
                  const SizedBox(height: AppSizes.lg),
                  if (maxBorrow > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Minutes to borrow:',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${selectedBorrow.round()} mins',
                          style: AppTextStyles.bodyLarge.copyWith(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: selectedBorrow,
                      min: 1,
                      max: maxBorrow.toDouble(),
                      divisions: maxBorrow > 1 ? maxBorrow - 1 : 1,
                      activeColor: Colors.white,
                      inactiveColor: AppColors.surfaceBorder,
                      onChanged: (val) {
                        setState(() {
                          selectedBorrow = val;
                        });
                      },
                    ),
                  ] else ...[
                    Text(
                      'Not enough credits remaining to borrow.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.only(bottom: AppSizes.md, right: AppSizes.md, left: AppSizes.md),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.surfaceBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: maxBorrow <= 0
                            ? null
                            : () async {
                                // Dismiss dialog first
                                Navigator.of(dialogContext).pop();
                                // Perform borrow
                                await ref.read(activeContractProvider.notifier).borrowMinutes(
                                      app.packageName,
                                      Duration(minutes: selectedBorrow.round()),
                                    );
                                // Dismiss overlay to let user use the app
                                ref.read(blockOverlayProvider.notifier).hideOverlay();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Borrow',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.brightness_1, size: 6, color: AppColors.textDisabled),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
