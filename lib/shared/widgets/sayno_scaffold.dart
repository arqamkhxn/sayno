import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Base scaffold for all SayNO screens.
/// Provides consistent background, padding, and safe area handling.
class SayNOScaffold extends StatelessWidget {
  const SayNOScaffold({
    required this.body,
    super.key,
    this.title,
    this.actions,
    this.padding,
    this.scrollable = true,
    this.appBar,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: scrollable
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
              child: body,
            )
          : Padding(
              padding: padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
              child: body,
            ),
    );
  }
}
