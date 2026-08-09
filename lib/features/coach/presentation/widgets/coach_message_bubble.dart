import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';

/// A single chat bubble from the AI coach.
class CoachMessageBubble extends StatelessWidget {
  const CoachMessageBubble({
    required this.message,
    required this.isCoach,
    super.key,
    this.timestamp,
  });

  final String message;
  final bool isCoach;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isCoach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm + 4,
              ),
              decoration: BoxDecoration(
                color: isCoach ? AppColors.surface : AppColors.surfaceElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppSizes.radiusMd),
                  topRight: const Radius.circular(AppSizes.radiusMd),
                  bottomLeft: Radius.circular(
                    isCoach ? AppSizes.xs : AppSizes.radiusMd,
                  ),
                  bottomRight: Radius.circular(
                    isCoach ? AppSizes.radiusMd : AppSizes.xs,
                  ),
                ),
                border: Border.all(
                  color: AppColors.surfaceBorder,
                  width: 1,
                ),
              ),
              child: Text(message, style: AppTextStyles.bodyMedium),
            ),
            if (timestamp != null) ...
              [
                const SizedBox(height: 4),
                Text(timestamp!, style: AppTextStyles.labelSmall),
              ],
          ],
        ),
      ),
    );
  }
}
