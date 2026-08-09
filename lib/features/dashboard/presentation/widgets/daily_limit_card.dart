import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/sayno_card.dart';
import '../../../../shared/widgets/sayno_progress_bar.dart';
import '../../../../theme/text_styles.dart';

/// Card showing daily usage limit and remaining time.
class DailyLimitCard extends StatelessWidget {
  const DailyLimitCard({
    required this.usedMinutes,
    required this.limitMinutes,
    super.key,
  });

  final int usedMinutes;
  final int limitMinutes;

  double get _progress =>
      (usedMinutes / limitMinutes).clamp(0.0, 1.0);

  int get _remainingMinutes => (limitMinutes - usedMinutes).clamp(0, limitMinutes);

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return SayNOCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.dailyLimitLabel, style: AppTextStyles.titleMedium),
              Text(
                _formatMinutes(limitMinutes),
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          SayNOProgressBar(value: _progress, height: 8),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: _LimitStat(
                  label: AppStrings.usedLabel,
                  value: _formatMinutes(usedMinutes),
                  color: _progress >= 0.85
                      ? AppColors.danger
                      : _progress >= 0.65
                          ? AppColors.warning
                          : AppColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.surfaceBorder,
              ),
              Expanded(
                child: _LimitStat(
                  label: AppStrings.remainingLabel,
                  value: _formatMinutes(_remainingMinutes),
                  color: AppColors.textPrimary,
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitStat extends StatelessWidget {
  const _LimitStat({
    required this.label,
    required this.value,
    required this.color,
    this.align = TextAlign.left,
  });

  final String label;
  final String value;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
