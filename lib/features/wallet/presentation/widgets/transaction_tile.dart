import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';

enum TransactionType { credit, debit, penalty }

/// A single transaction row in the wallet history.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    super.key,
  });

  final String title;
  final double amount;
  final TransactionType type;
  final String date;

  Color get _color => switch (type) {
        TransactionType.credit => AppColors.success,
        TransactionType.debit => AppColors.textSecondary,
        TransactionType.penalty => AppColors.danger,
      };

  IconData get _icon => switch (type) {
        TransactionType.credit => Icons.arrow_downward_rounded,
        TransactionType.debit => Icons.arrow_upward_rounded,
        TransactionType.penalty => Icons.warning_amber_rounded,
      };

  String get _prefix => switch (type) {
        TransactionType.credit => '+',
        TransactionType.debit => '-',
        TransactionType.penalty => '-',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(_icon, size: AppSizes.iconSm, color: _color),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Text(date, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            '$_prefix\$${amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}
