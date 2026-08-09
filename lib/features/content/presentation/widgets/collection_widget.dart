import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../theme/text_styles.dart';
import '../../domain/content_collection.dart';
import 'content_card_widget.dart';

class CollectionWidget extends StatelessWidget {
  final ContentCollection collection;

  const CollectionWidget({
    required this.collection,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                collection.title,
                style: AppTextStyles.titleLarge,
              ),
              if (collection.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  collection.subtitle!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          height: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: collection.items.length,
            itemBuilder: (context, index) {
              return ContentCardWidget(item: collection.items[index]);
            },
          ),
        ),
      ],
    );
  }
}
