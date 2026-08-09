import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/sayno_card.dart';
import '../../../../theme/text_styles.dart';

/// Bar chart showing daily usage over the past 7 days.
class UsageChart extends StatelessWidget {
  const UsageChart({required this.weeklyData, super.key});

  /// Minutes per day, index 0 = oldest, index 6 = today.
  final List<double> weeklyData;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final maxY = (weeklyData.reduce((a, b) => a > b ? a : b) * 1.3)
        .clamp(60.0, double.infinity);

    return SayNOCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Usage', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSizes.lg),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.surfaceBorder,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= _dayLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _dayLabels[index],
                            style: AppTextStyles.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: weeklyData.indexed.map((entry) {
                  final index = entry.$1;
                  final value = entry.$2;
                  final isToday = index == weeklyData.length - 1;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: isToday
                            ? AppColors.textPrimary
                            : AppColors.surfaceElevated,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
