import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import 'identity_flow_provider.dart';

class IdentityGoalsScreen extends ConsumerStatefulWidget {
  const IdentityGoalsScreen({super.key});

  @override
  ConsumerState<IdentityGoalsScreen> createState() => _IdentityGoalsScreenState();
}

class _IdentityGoalsScreenState extends ConsumerState<IdentityGoalsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleGoal(int identityIndex, String goal) {
    final identities = List.of(ref.read(identityFlowProvider));
    final identity = identities[identityIndex];
    final selectedGoals = List<String>.from(identity.selectedGoals);

    if (selectedGoals.contains(goal)) {
      selectedGoals.remove(goal);
    } else {
      selectedGoals.add(goal);
    }

    identities[identityIndex] = identity.copyWith(selectedGoals: selectedGoals);
    ref.read(identityFlowProvider.notifier).state = identities;
  }

  void _onNext() {
    final identities = ref.read(identityFlowProvider);
    if (_currentIndex < identities.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.push('/identity/review');
    }
  }

  @override
  Widget build(BuildContext context) {
    final identities = ref.watch(identityFlowProvider);

    if (identities.isEmpty) {
      return const SayNOScaffold(body: Center(child: Text('No identities selected')));
    }

    return SayNOScaffold(
      scrollable: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set Goals',
                style: AppTextStyles.headlineLarge,
              ),
              Text(
                '${_currentIndex + 1} / ${identities.length}',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Force button usage
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: identities.length,
              itemBuilder: (context, index) {
                final identity = identities[index];
                return _buildGoalSelection(index, identity);
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: SayNOButton(
              label: _currentIndex < identities.length - 1 ? 'Next' : 'Review',
              onPressed: _onNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSelection(int identityIndex, identity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For your ${identity.profile.label} identity',
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Select areas you want to focus on.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.xl),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: identity.profile.defaultGoals.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
            itemBuilder: (context, i) {
              final goal = identity.profile.defaultGoals[i];
              final isSelected = identity.selectedGoals.contains(goal);

              return InkWell(
                onTap: () => _toggleGoal(identityIndex, goal),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withOpacity(0.2) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goal,
                        style: AppTextStyles.titleMedium,
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.accent)
                      else
                        const Icon(Icons.circle_outlined, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
