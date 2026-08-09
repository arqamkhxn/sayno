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
import '../domain/contract_day_record.dart';

class ContractCompletionScreen extends ConsumerStatefulWidget {
  const ContractCompletionScreen({super.key});

  @override
  ConsumerState<ContractCompletionScreen> createState() => _ContractCompletionScreenState();
}

class _ContractCompletionScreenState extends ConsumerState<ContractCompletionScreen> {
  bool _isFinalizing = false;

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
      body: SafeArea(
        child: activeContractAsync.when(
          data: (contract) {
            if (contract == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            return _buildCompletionContent(contract);
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (err, _) => Center(
            child: Text(
              'Error loading completion details: $err',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionContent(Contract contract) {
    final calendarAsync = ref.watch(contractCalendarProvider(contract.id!));

    return calendarAsync.when(
      data: (records) {
        final greenDays = records.where((r) => r.status == ContractDayStatus.green).length;
        final redDays = records.where((r) => r.status == ContractDayStatus.red).length;
        final successRate = contract.durationDays > 0
            ? ((greenDays / contract.durationDays) * 100).round()
            : 0;

        final isPerfect = redDays == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSizes.lg),
                      // Trophy/Medal Icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSizes.xl),
                          decoration: BoxDecoration(
                            color: (isPerfect ? const Color(0xFFFFD700) : Colors.blueGrey).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isPerfect ? const Color(0xFFFFD700) : Colors.blueGrey).withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isPerfect ? Icons.emoji_events_rounded : Icons.shield_rounded,
                            color: isPerfect ? const Color(0xFFFFD700) : Colors.blueGrey,
                            size: 80,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      // Success/Completion Headers
                      Center(
                        child: Text(
                          isPerfect ? 'Perfect Commitment!' : 'Contract Completed',
                          style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Center(
                        child: Text(
                          isPerfect
                              ? 'You successfully kept all daily limits for ${contract.durationDays} days.'
                              : 'You finished the commitment. Here is your final summary.',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      // Metrics Summary Cards
                      _buildMetricsSummaryCard(contract, greenDays, redDays, successRate),
                      const SizedBox(height: AppSizes.lg),
                      // Credit pools utilization
                      Text(
                        'Credit Pool Remaining:',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: contract.apps.length,
                        itemBuilder: (context, index) {
                          final app = contract.apps[index];
                          final label = monitoredAppsRegistry[app.packageName] ?? app.packageName.split('.').last;
                          final total = app.totalCredits.inMinutes;
                          final remaining = app.remainingCredits.inMinutes;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(label, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                                  Text('$remaining / $total mins remaining',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSizes.lg),
                    ],
                  ),
                ),
              ),
              // Complete Button
              ElevatedButton(
                onPressed: _isFinalizing
                    ? null
                    : () async {
                        setState(() => _isFinalizing = true);
                        try {
                          final finalStatus = isPerfect ? ContractStatus.completed : ContractStatus.failed;
                          await ref.read(activeContractProvider.notifier).completeActiveContract(finalStatus);
                        } finally {
                          if (mounted) {
                            setState(() => _isFinalizing = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
                child: _isFinalizing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        'Archive & Complete Contract',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: AppSizes.lg),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, _) => Center(
        child: Text(
          'Error loading days: $err',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
        ),
      ),
    );
  }

  Widget _buildMetricsSummaryCard(Contract contract, int greenDays, int redDays, int successRate) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('Duration', '${contract.durationDays}d'),
              _buildMetricItem('Success Rate', '$successRate%'),
              _buildMetricItem('Max Streak', '${contract.longestStreak}d'),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          const Divider(color: AppColors.surfaceBorder),
          const SizedBox(height: AppSizes.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  const SizedBox(width: 6),
                  Text('$greenDays Perfect Days', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 16),
                  const SizedBox(width: 6),
                  Text('$redDays Violation Days', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.numericLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
