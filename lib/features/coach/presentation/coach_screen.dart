import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../theme/text_styles.dart';
import '../application/coach_controller.dart';
import 'widgets/coach_input_bar.dart';
import 'widgets/coach_message_bubble.dart';

class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(coachControllerProvider);
    final messages = chatState.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.coachTitle, style: AppTextStyles.headlineSmall),
            Text(
              AppStrings.coachSubtitle,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.md),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              physics: const BouncingScrollPhysics(),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
              itemBuilder: (context, index) {
                final msg = messages[index];
                return CoachMessageBubble(
                  message: msg.text,
                  isCoach: msg.role == 'model',
                  timestamp: DateFormat.jm().format(msg.timestamp),
                );
              },
            ),
          ),
          const CoachInputBar(),
        ],
      ),
    );
  }
}
