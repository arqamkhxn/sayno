import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/sayno_progress_bar.dart';
import '../../../../theme/text_styles.dart';

/// A single row showing an app's usage relative to its limit.
class AppUsageTile extends StatelessWidget {
  const AppUsageTile({
    required this.appName,
    required this.usedMinutes,
    required this.icon,
    this.limitMinutes,
    super.key,
  });

  final String appName;
  final int usedMinutes;
  final int? limitMinutes;
  final IconData icon;

  double get _progress {
    final limit = limitMinutes;
    if (limit == null || limit <= 0) return 0.0;
    return (usedMinutes / limit).clamp(0.0, 1.0);
  }

  String _fmt(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    return h > 0 ? '${h}h ${min}m' : '${min}m';
  }

  @override
  Widget build(BuildContext context) {
    final limit = limitMinutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, size: AppSizes.iconSm, color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(appName, style: AppTextStyles.titleMedium),
                        Text(
                          limit != null && limit > 0
                              ? '${_fmt(usedMinutes)} / ${_fmt(limit)}'
                              : '${_fmt(usedMinutes)} / Unlimited',
                          style: AppTextStyles.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.xs),
                    SayNOProgressBar(value: _progress, height: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
