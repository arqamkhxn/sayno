import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/sayno_card.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../shared/widgets/sayno_section_header.dart';
import '../../../theme/text_styles.dart';
import 'widgets/balance_card.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/wallet_action_row.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SayNOScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.lg),
          Text(AppStrings.walletTitle, style: AppTextStyles.headlineLarge),
          const SizedBox(height: AppSizes.xs),
          Text(
            AppStrings.walletComingSoon,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const BalanceCard(balanceAmount: 0.00),
          const SizedBox(height: AppSizes.lg),
          const WalletActionRow(),
          const SizedBox(height: AppSizes.lg),
          const SayNOSectionHeader(title: AppStrings.transactions),
          const SizedBox(height: AppSizes.md),
          SayNOCard(
            child: Column(
              children: [
                const TransactionTile(
                  title: 'Initial Deposit',
                  amount: 10.00,
                  type: TransactionType.credit,
                  date: 'Jun 10, 2025',
                ),
                const Divider(),
                const TransactionTile(
                  title: 'Penalty Charge',
                  amount: 2.50,
                  type: TransactionType.penalty,
                  date: 'Jun 12, 2025',
                ),
                const Divider(),
                const TransactionTile(
                  title: 'Borrowed Minutes',
                  amount: 1.00,
                  type: TransactionType.debit,
                  date: 'Jun 14, 2025',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }
}
