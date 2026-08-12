import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/sayno_card.dart';
import '../../../shared/widgets/sayno_chip.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../shared/widgets/sayno_section_header.dart';
import '../../../theme/text_styles.dart';
import '../../protection/application/app_detection_controller.dart';
import '../../protection/application/limit_controller.dart';
import '../../protection/application/protection_controller.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/domain/protection_status.dart';
import 'widgets/daily_limit_card.dart';
import 'widgets/quick_stats_row.dart';
import 'widgets/status_banner.dart';
import 'widgets/streak_card.dart';
 
import 'package:go_router/go_router.dart';
import '../../contract/application/contract_controller.dart';
import '../../contract/domain/contract.dart';
import '../../protection/domain/monitored_apps.dart';
import '../../auth/application/auth_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final protectionStatus = ref.watch(protectionControllerProvider).when(
          data: (status) => status,
          error: (_, __) => ProtectionStatus.unknown,
          loading: () => ProtectionStatus.unknown,
        );
    final sessionCount = ref.watch(sessionCountProvider);
    final todayTotalUsage = ref.watch(todayTotalUsageProvider);
    final activeContractAsync = ref.watch(activeContractProvider);
    final activeContract = activeContractAsync.value;

    int totalLimitMinutes = 0;
    if (activeContract != null) {
      for (final app in activeContract.apps) {
        totalLimitMinutes += app.dailyLimit.inMinutes;
      }
    } else {
      final phase2Limits = ref.watch(appLimitsProvider).value ?? const {};
      for (final limit in phase2Limits.values) {
        totalLimitMinutes += limit.inMinutes;
      }
    }

    final totalUsedMinutes = todayTotalUsage.inMinutes;
    final int focusScore = (totalLimitMinutes == 0) 
        ? 100 
        : (100 - ((totalUsedMinutes / totalLimitMinutes) * 100)).clamp(0, 100).toInt();
 
    return SayNOScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSizes.lg),
              const _DashboardHeader(),
              const SizedBox(height: AppSizes.lg),
              if (protectionStatus != ProtectionStatus.protected) ...[
                StatusBanner(
                  status: protectionStatus,
                  onTap: () {
                    if (protectionStatus == ProtectionStatus.protectionRequired) {
                      ref.read(protectionPlatformServiceProvider).openAccessibilitySettings();
                    }
                  },
                ),
                const SizedBox(height: AppSizes.md),
              ],
              const _ActiveAppStatusCard(),
              const SizedBox(height: AppSizes.md),
              StreakCard(streakDays: activeContract?.currentStreak ?? 0),
              const SizedBox(height: AppSizes.md),
              DailyLimitCard(usedMinutes: totalUsedMinutes, limitMinutes: totalLimitMinutes),
              const SizedBox(height: AppSizes.lg),
              const SayNOSectionHeader(title: 'Today'),
              const SizedBox(height: AppSizes.md),
              QuickStatsRow(
                blockedToday: 0,
                sessionCount: sessionCount,
                focusScore: focusScore,
              ),
              const SizedBox(height: AppSizes.lg),
              const SayNOSectionHeader(title: AppStrings.contractLabel),
            const SizedBox(height: AppSizes.md),
            activeContractAsync.when(
              data: (contract) {
                if (contract == null) {
                  return _ContractPlaceholder();
                }
                return _ContractProgressCard(contract: contract);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              error: (_, __) => _ContractPlaceholder(),
            ),
            const SizedBox(height: AppSizes.xxl),
          ],
        ),
      ),
    ),
  );
  }
}
 
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider).value;
    final session = ref.watch(authStateProvider).value;
    
    final displayLabel = username != null && username.isNotEmpty 
        ? '@$username' 
        : session?.displayName ?? 'SayNO User';
        
    final initial = displayLabel.isNotEmpty 
        ? (displayLabel.startsWith('@') ? displayLabel[1].toUpperCase() : displayLabel[0].toUpperCase())
        : 'U';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF9CA3AF),
              ),
            ),
            Text(displayLabel, style: AppTextStyles.headlineLarge),
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: const Color(0xFF222222), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: AppTextStyles.titleMedium.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
 
class _ContractPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: const Color(0xFF222222), width: 1),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 32,
            color: Color(0xFF4B5563),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            AppStrings.noContract,
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          ElevatedButton(
            onPressed: () => context.push('/contract/create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF222222),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Create Contract'),
          ),
        ],
      ),
    );
  }
}

class _ContractProgressCard extends ConsumerWidget {
  final Contract contract;
  const _ContractProgressCard({required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayUsage = ref.watch(contractTodayUsageProvider);
    final nowUtc = getSystemTime().toUtc();
    final dayNum = contract.currentDayNumber(nowUtc);

    int totalRemainingSec = 0;
    for (final app in contract.apps) {
      final todayAppUsage = todayUsage[app.packageName] ?? Duration.zero;
      final appRemaining = app.remainingCredits - todayAppUsage;
      totalRemainingSec += appRemaining.inSeconds;
    }
    final remainingCredits = Duration(seconds: totalRemainingSec);

    return InkWell(
      onTap: () => context.push('/contract/calendar'),
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: const Color(0xFF222222), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $dayNum of ${contract.durationDays}',
                  style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Streak: ${contract.currentStreak} 🔥',
                  style: AppTextStyles.titleMedium.copyWith(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            const Divider(color: Color(0xFF222222)),
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Budget Remaining:',
                  style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
                ),
                Text(
                  '${remainingCredits.inMinutes} mins',
                  style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              "Today's Apps Usage:",
              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: AppSizes.xs),
            ...contract.apps.map((app) {
              final usage = todayUsage[app.packageName] ?? Duration.zero;
              final limit = app.dailyLimit;
              final appLabel = monitoredAppsRegistry[app.packageName] ?? app.packageName.split('.').last;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appLabel,
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${usage.inMinutes} / ${limit.inMinutes} mins',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: usage.inSeconds >= limit.inSeconds
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppSizes.md),
            Center(
              child: Text(
                'Tap to view Calendar & History',
                style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _ActiveAppStatusCard extends ConsumerWidget {
  const _ActiveAppStatusCard();
 
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
 
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
 
    if (hours > 0) {
      final hoursStr = hours.toString().padLeft(2, '0');
      return '$hoursStr:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }
 
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('UI: DashboardScreen build() called');
    final activeAppName = ref.watch(activeAppNameProvider);
    final isMonitored = ref.watch(isMonitoredAppActiveProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final isLimitReached = ref.watch(isActiveAppLimitReachedProvider);
 
    final Color accentColor = isLimitReached
        ? const Color(0xFFEF4444) // Danger Red
        : const Color(0xFFFFD700); // Monitored Yellow
 
    return SayNOCard(
      backgroundColor: isMonitored
          ? accentColor.withValues(alpha: 0.08)
          : const Color(0xFF111111),
      borderColor: isMonitored
          ? accentColor.withValues(alpha: 0.2)
          : const Color(0xFF222222),
      child: Row(
        children: [
          Icon(
            isMonitored ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: isMonitored ? accentColor : const Color(0xFF9CA3AF),
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMonitored ? 'Active App' : 'App Detection',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                Text(
                  isMonitored
                      ? '$activeAppName (${_formatDuration(activeSession?.duration ?? Duration.zero)})'
                      : 'No Monitored App Active',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isMonitored ? accentColor : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isMonitored)
            SayNOChip(
              label: isLimitReached ? 'LIMIT REACHED' : 'MONITORED',
              color: accentColor,
            ),
        ],
      ),
    );
  }
}
