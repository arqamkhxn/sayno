import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/sayno_card.dart';
import '../../../../shared/widgets/sayno_stat_tile.dart';

/// A row of quick stat tiles on the dashboard.
class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({
    required this.blockedToday,
    required this.sessionCount,
    required this.focusScore,
    super.key,
  });

  final int blockedToday;
  final int sessionCount;
  final int focusScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SayNOCard(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SayNOStatTile(
              label: 'Blocked',
              value: '$blockedToday',
              icon: Icons.block_rounded,
              valueColor: blockedToday > 0
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: SayNOCard(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SayNOStatTile(
              label: 'Sessions',
              value: '$sessionCount',
              icon: Icons.timer_outlined,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: SayNOCard(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SayNOStatTile(
              label: 'Focus',
              value: '$focusScore%',
              icon: Icons.track_changes_rounded,
              valueColor: focusScore >= 80
                  ? AppColors.success
                  : focusScore >= 50
                      ? AppColors.warning
                      : AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }
}
