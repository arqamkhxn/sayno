import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../theme/text_styles.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/domain/monitored_apps.dart';
import '../application/contract_controller.dart';
import '../domain/contract.dart';
import '../domain/contract_app.dart';
import '../domain/contract_day_record.dart';

class ContractCalendarScreen extends ConsumerStatefulWidget {
  const ContractCalendarScreen({super.key});

  @override
  ConsumerState<ContractCalendarScreen> createState() => _ContractCalendarScreenState();
}

class _ContractCalendarScreenState extends ConsumerState<ContractCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contractValidationServiceProvider).performValidation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeContractAsync = ref.watch(activeContractProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Contract Calendar',
          style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: activeContractAsync.when(
        data: (contract) {
          if (contract == null) {
            return Center(
              child: Text(
                'No active contract',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            );
          }
          return _buildCalendarContent(contract);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) => Center(
          child: Text(
            'Error loading contract: $err',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarContent(Contract contract) {
    final calendarAsync = ref.watch(contractCalendarProvider(contract.id!));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.md),
          // Streak and progress summary
          _buildStreakSummary(contract),
          const SizedBox(height: AppSizes.lg),
          // Calendar Grid
          Text(
            'Commitment Calendar',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSizes.sm),
          calendarAsync.when(
            data: (records) => _buildGrid(contract, records),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.lg),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Text('Error loading days: $err', style: TextStyle(color: AppColors.danger)),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _buildLegend(),
          const SizedBox(height: AppSizes.xl),
          // App Credit Pools
          Text(
            'App Credit Pools',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSizes.md),
          ...contract.apps.map((app) => _buildAppCreditCard(app, contract.durationDays)),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }

  Widget _buildStreakSummary(Contract contract) {
    final nowUtc = getSystemTime().toUtc();
    final dayNum = contract.currentDayNumber(nowUtc);

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'Day',
            '$dayNum / ${contract.durationDays}',
            Icons.calendar_today_rounded,
            Colors.blueAccent,
          ),
          Container(height: 40, width: 1, color: AppColors.surfaceBorder),
          _buildSummaryItem(
            'Current Streak',
            '${contract.currentStreak} days',
            Icons.local_fire_department_rounded,
            AppColors.warning,
          ),
          Container(height: 40, width: 1, color: AppColors.surfaceBorder),
          _buildSummaryItem(
            'Longest Streak',
            '${contract.longestStreak} days',
            Icons.emoji_events_rounded,
            const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: AppSizes.xs),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGrid(Contract contract, List<ContractDayRecord> records) {
    final recordMap = {for (var r in records) r.dateUtc: r.status};
    final nowUtc = getSystemTime().toUtc();
    final todayUtcStr = nowUtc.toIso8601String().substring(0, 10);
    final startUtc = contract.startTimestampUtc.toUtc();
    final startLocalDate = DateTime.utc(startUtc.year, startUtc.month, startUtc.day);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: AppSizes.sm,
        mainAxisSpacing: AppSizes.sm,
        childAspectRatio: 1.0,
      ),
      itemCount: contract.durationDays,
      itemBuilder: (context, index) {
        final dayIndex = index + 1;
        final dayDate = startLocalDate.add(Duration(days: index));
        final dateStr = dayDate.toIso8601String().substring(0, 10);

        final isToday = dateStr == todayUtcStr;
        final isFuture = dayDate.isAfter(DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day));
        final status = recordMap[dateStr];

        Color cellBg = AppColors.surface;
        Color borderColor = AppColors.surfaceBorder;
        Widget? statusWidget;

        if (status == ContractDayStatus.green) {
          cellBg = AppColors.success.withValues(alpha: 0.15);
          borderColor = AppColors.success.withValues(alpha: 0.8);
          statusWidget = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14);
        } else if (status == ContractDayStatus.red) {
          cellBg = AppColors.danger.withValues(alpha: 0.15);
          borderColor = AppColors.danger.withValues(alpha: 0.8);
          statusWidget = const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 14);
        } else if (isToday) {
          borderColor = Colors.white.withValues(alpha: 0.6);
          statusWidget = Text(
            'TODAY',
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
          );
        } else if (isFuture) {
          cellBg = AppColors.surface.withValues(alpha: 0.4);
          borderColor = AppColors.surfaceBorder.withValues(alpha: 0.5);
        } else {
          // Past day that has not been synced or written yet
          borderColor = AppColors.surfaceBorder;
        }

        return Container(
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Day $dayIndex',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isFuture ? AppColors.textDisabled : AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
              if (statusWidget != null) ...[
                const SizedBox(height: 4),
                statusWidget,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Legend', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Success', AppColors.success),
              _buildLegendItem('Violation', AppColors.danger),
              _buildLegendItem('Today', Colors.white.withValues(alpha: 0.6)),
              _buildLegendItem('Future', AppColors.surfaceBorder),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildAppCreditCard(ContractApp app, int durationDays) {
    final todayUsage = ref.watch(contractTodayUsageProvider);
    final todayAppUsage = todayUsage[app.packageName] ?? Duration.zero;
    final remainingCredits = app.remainingCredits - todayAppUsage;

    final appLabel = monitoredAppsRegistry[app.packageName] ?? app.packageName.split('.').last;
    final double progress = app.totalCredits.inSeconds > 0
        ? remainingCredits.inSeconds / app.totalCredits.inSeconds
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appLabel,
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              Text(
                '${remainingCredits.inMinutes} / ${app.totalCredits.inMinutes} mins',
                style: AppTextStyles.titleMedium.copyWith(
                  color: remainingCredits > Duration.zero ? const Color(0xFFFFD700) : AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Daily Limit: ${app.dailyLimit.inMinutes} mins/day',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceBorder,
              color: remainingCredits > Duration.zero ? const Color(0xFFFFD700) : AppColors.danger,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
