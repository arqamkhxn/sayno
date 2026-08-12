import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/sayno_card.dart';
import '../../../../shared/widgets/sayno_stat_tile.dart';
import '../../../../theme/text_styles.dart';

/// Summary card showing weekly screen time stats.
class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({
    required this.totalHours,
    required this.dailyAvgMinutes,
    required this.bestDayLabel,
    super.key,
  });

  final double totalHours;
  final int dailyAvgMinutes;
  final String bestDayLabel;

  String _fmtAvg(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    return h > 0 ? '${h}h ${min}m' : '${min}m';
  }

  @override
  Widget build(BuildContext context) {
    return SayNOCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: SayNOStatTile(
                  label: 'Total',
                  value: '${totalHours.toStringAsFixed(1)}h',
                ),
              ),
              Expanded(
                child: SayNOStatTile(
                  label: 'Daily Avg',
                  value: _fmtAvg(dailyAvgMinutes),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: AppSizes.iconSm,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSizes.xs),
                Text(
                  'Best day: $bestDayLabel',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
