import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/release_controller.dart';
import '../domain/release_request.dart';

class ReleaseCooldownScreen extends ConsumerWidget {
  const ReleaseCooldownScreen({super.key});

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releaseState = ref.watch(releaseControllerProvider);
    final activeRequest = releaseState.activeRequest;
    final remainingTime = releaseState.remainingTime;

    if (releaseState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/verification-error');
      });
      return const SayNOScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Auto redirect if there is no active request and we are not loading
    if (activeRequest == null && !releaseState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/settings');
      });
      return const SayNOScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (releaseState.isLoading) {
      return const SayNOScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isCompleted = activeRequest?.status == ReleaseStatus.completed;
    final isPendingApproval = activeRequest?.status == ReleaseStatus.pending_approval;
    final isGraceWindow = activeRequest?.status == ReleaseStatus.grace_window;

    double progress = 0.0;
    if (activeRequest != null && remainingTime != null) {
      if (activeRequest.status == ReleaseStatus.cooldown) {
        final total = activeRequest.cooldownDurationSeconds;
        final remaining = remainingTime.inSeconds;
        final elapsed = total - remaining;
        progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 1.0;
      } else if (activeRequest.status == ReleaseStatus.grace_window) {
        final total = activeRequest.cooldownDurationSeconds <= 60 ? 60 : 86400;
        final remaining = remainingTime.inSeconds;
        final elapsed = total - remaining;
        progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 1.0;
      }
    }

    return SayNOScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            if (isCompleted) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.xl),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 100,
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              Text(
                'Release Authorized',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                'SayNO protection has been deactivated. You can now disable the Accessibility service or uninstall the application.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xxl),
              SayNOButton(
                label: 'Return to Settings',
                onPressed: () {
                  context.go('/settings');
                },
              ),
            ] else if (isPendingApproval) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.xl),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  color: AppColors.warning,
                  size: 100,
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              Text(
                'Pending Partner Approval',
                style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                'Cooldown has completed. Your release is waiting for approval from your accountability partner.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xxl),
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.md),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Text(
                        'Warning shields and Settings locks remain fully active until your partner approves.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              SayNOButton(
                label: 'Cancel Request',
                variant: SayNOButtonVariant.secondary,
                onPressed: () async {
                  await ref.read(releaseControllerProvider.notifier).cancelRelease();
                },
              ),
            ] else if (isGraceWindow) ...[
              Text(
                'Grace Window Active',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                'You can cancel deactivation at any time during this grace period.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xxl),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 16,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDuration(remainingTime),
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          'GRACE PERIOD',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xxl),
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.md),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Text(
                        'Deactivation will finalize automatically when the grace period expires.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              SayNOButton(
                label: 'Cancel Request (Re-Lock)',
                variant: SayNOButtonVariant.secondary,
                onPressed: () async {
                  await ref.read(releaseControllerProvider.notifier).cancelRelease();
                },
              ),
            ] else ...[
              Text(
                'Deactivation Cooldown',
                style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                'Release Request is processing',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xxl),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 16,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDuration(remainingTime),
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          'REMAINING',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xxl),
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.md),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Text(
                        'Protection warning overlays and Settings blocks remain fully active until the cooldown completes.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              SayNOButton(
                label: 'Cancel Request',
                variant: SayNOButtonVariant.secondary,
                onPressed: () async {
                  await ref.read(releaseControllerProvider.notifier).cancelRelease();
                },
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
