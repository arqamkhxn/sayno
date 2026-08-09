import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/sayno_button.dart';
import '../../../../shared/widgets/sayno_card.dart';
import '../../../../theme/text_styles.dart';

/// Hero balance card for the wallet screen.
class BalanceCard extends StatelessWidget {
  const BalanceCard({required this.balanceAmount, super.key});

  final double balanceAmount;

  @override
  Widget build(BuildContext context) {
    return SayNOCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.balance,
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            '\$${balanceAmount.toStringAsFixed(2)}',
            style: AppTextStyles.numericHero,
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: SayNOButton(
                  label: AppStrings.addFunds,
                  onPressed: null,
                  icon: Icons.add_rounded,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: SayNOButton(
                  label: AppStrings.withdraw,
                  onPressed: null,
                  variant: SayNOButtonVariant.secondary,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
