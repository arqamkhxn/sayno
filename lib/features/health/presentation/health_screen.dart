import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/sayno_card.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../shared/widgets/sayno_section_header.dart';
import '../../../theme/text_styles.dart';
import '../../protection/application/limit_controller.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/domain/monitored_apps.dart';
import 'widgets/app_usage_tile.dart';
import 'widgets/usage_chart.dart';
import 'widgets/weekly_summary_card.dart';
import '../application/health_controller.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  IconData _getIconForPackage(String package) {
    switch (package) {
      case 'com.instagram.android':
        return Icons.photo_camera_outlined;
      case 'com.google.android.youtube':
        return Icons.play_circle_outline_rounded;
      case 'com.facebook.katana':
      case 'com.facebook.lite':
        return Icons.facebook_outlined;
      case 'com.android.chrome':
      case 'com.microsoft.emmx':
      case 'org.mozilla.firefox':
      case 'com.brave.browser':
        return Icons.language_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch today's per-app usage and configured limits
    final todayUsage = ref.watch(todayAppUsageProvider);
    final appLimitsAsync = ref.watch(appLimitsProvider);
    final appLimits = appLimitsAsync.value ?? const {};

    // Determine packages to show: only apps with usage > 0 or configured limit
    final allPackages = <String>{...appLimits.keys, ...todayUsage.keys}.toList();
    final displayedPackages = allPackages.where((package) {
      final usedMinutes = todayUsage[package]?.inMinutes ?? 0;
      final limitMinutes = appLimits[package]?.inMinutes;
      return usedMinutes > 0 || limitMinutes != null;
    }).toList();

    // Sort descending by usage
    displayedPackages.sort((a, b) {
      final usageA = todayUsage[a]?.inMinutes ?? 0;
      final usageB = todayUsage[b]?.inMinutes ?? 0;
      return usageB.compareTo(usageA);
    });

    final weeklyDataAsync = ref.watch(weeklyUsageProvider);
    final summaryDataAsync = ref.watch(weeklySummaryProvider);

    return SayNOScaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSizes.md),
              summaryDataAsync.when(
                data: (summary) => WeeklySummaryCard(
                  totalHours: summary.totalHours,
                  dailyAvgMinutes: summary.dailyAvgMinutes,
                  bestDayLabel: summary.bestDayLabel,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => const Center(child: Text('Unable to load stats')),
              ),
              const SizedBox(height: AppSizes.md),
          
          weeklyDataAsync.when(
            data: (weeklyData) {
              final chartData = weeklyData.map((stat) => stat.totalDuration.inMinutes.toDouble()).toList();
              // Prevent crashing if the list is empty (should always have 7 from provider)
              if (chartData.isEmpty) return const SizedBox.shrink();
              return UsageChart(weeklyData: chartData);
            },
            loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => const SizedBox.shrink(),
          ),
          
          const SizedBox(height: AppSizes.lg),
          const SayNOSectionHeader(title: AppStrings.appUsage),
          const SizedBox(height: AppSizes.md),
          SayNOCard(
            child: displayedPackages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Center(
                      child: Text(
                        'No app usage tracked today',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < displayedPackages.length; i++) ...[
                        if (i > 0) const Divider(),
                        Builder(
                          builder: (context) {
                            final package = displayedPackages[i];
                            final appName = monitoredAppsRegistry[package] ?? 'Unknown App';
                            final usedMinutes = todayUsage[package]?.inMinutes ?? 0;
                            final limitMinutes = appLimits[package]?.inMinutes;

                            return AppUsageTile(
                              appName: appName,
                              usedMinutes: usedMinutes,
                              limitMinutes: limitMinutes,
                              icon: _getIconForPackage(package),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    ),
  ),
);
  }
}
