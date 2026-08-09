import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/home_controller.dart';
import 'widgets/collection_widget.dart';

class IntentionalHomeScreen extends ConsumerWidget {
  const IntentionalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(homeControllerProvider);

    return SayNOScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: collectionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Failed to load content', style: AppTextStyles.bodyMedium),
          ),
          data: (collections) {
            if (collections.isEmpty) {
              return Center(
                child: Text('No content available', style: AppTextStyles.bodyMedium),
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                        Text(
                          'Intentional Home',
                          style: AppTextStyles.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.xxl),
                        child: CollectionWidget(collection: collections[index]),
                      );
                    },
                    childCount: collections.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
