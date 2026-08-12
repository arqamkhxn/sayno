import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../navigation/nav_destinations.dart';
import '../../theme/text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/widgets/guest_login_banner.dart';

/// Root scaffold that wraps all tab screens with the bottom navigation bar.
class AppScaffoldWithNav extends ConsumerWidget {
  const AppScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuestMode = ref.watch(guestModeProvider);
    final authState = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (isGuestMode && authState == null) const GuestLoginBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: SayNOBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

/// SayNO bottom navigation bar.
class SayNOBottomNav extends StatelessWidget {
  const SayNOBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: NavDestination.values.indexed.map((entry) {
              final index = entry.$1;
              final destination = entry.$2;
              final isSelected = index == currentIndex;

              return _NavItem(
                destination: destination,
                isSelected: isSelected,
                onTap: () => onDestinationSelected(index),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                key: ValueKey(isSelected),
                size: AppSizes.iconMd,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
