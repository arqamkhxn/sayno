import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import 'identity_flow_provider.dart';
import '../domain/user_identity.dart';

class IdentityPriorityScreen extends ConsumerStatefulWidget {
  const IdentityPriorityScreen({super.key});

  @override
  ConsumerState<IdentityPriorityScreen> createState() => _IdentityPriorityScreenState();
}

class _IdentityPriorityScreenState extends ConsumerState<IdentityPriorityScreen> {
  List<UserIdentity> _identities = [];

  @override
  void initState() {
    super.initState();
    _identities = List.from(ref.read(identityFlowProvider));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _identities.removeAt(oldIndex);
      _identities.insert(newIndex, item);
      
      // Update priorities
      for (int i = 0; i < _identities.length; i++) {
        _identities[i] = _identities[i].copyWith(priority: i + 1);
      }
    });
  }

  void _onNext() {
    ref.read(identityFlowProvider.notifier).state = _identities;
    context.push('/identity/goals');
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Prioritize',
            style: AppTextStyles.headlineLarge,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Drag to order by importance to you.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.xl),

          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _identities.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final identity = _identities[index];
                return Container(
                  key: ValueKey(identity.profile.id),
                  margin: const EdgeInsets.only(bottom: AppSizes.md),
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Text(
                          identity.profile.label,
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                    ],
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: SayNOButton(
              label: 'Continue',
              onPressed: _onNext,
            ),
          ),
        ],
      ),
    );
  }
}
