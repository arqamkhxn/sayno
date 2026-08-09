import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../theme/text_styles.dart';
import '../../application/coach_controller.dart';

/// Input bar at the bottom of the coach screen.
class CoachInputBar extends ConsumerStatefulWidget {
  const CoachInputBar({super.key});

  @override
  ConsumerState<CoachInputBar> createState() => _CoachInputBarState();
}

class _CoachInputBarState extends ConsumerState<CoachInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(coachControllerProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    // Disable input while loading
    final isLoading = ref.watch(coachControllerProvider).isLoading;

    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.md,
        right: AppSizes.md,
        top: AppSizes.sm,
        bottom: MediaQuery.paddingOf(context).bottom + AppSizes.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                border: Border.all(color: AppColors.surfaceBorder, width: 1),
              ),
              child: TextField(
                controller: _controller,
                enabled: !isLoading,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: AppStrings.coachPlaceholder,
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textDisabled,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.sm + 2),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          GestureDetector(
            onTap: isLoading ? null : _submit,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLoading ? AppColors.surfaceBorder : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textDisabled,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.background,
                      size: AppSizes.iconMd,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
