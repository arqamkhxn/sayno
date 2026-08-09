import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';

/// Defines each bottom navigation destination.
enum NavDestination {
  dashboard(
    label: AppStrings.navDashboard,
    icon: Icons.grid_view_rounded,
    selectedIcon: Icons.grid_view_rounded,
    route: '/dashboard',
  ),
  health(
    label: AppStrings.navHealth,
    icon: Icons.favorite_border_rounded,
    selectedIcon: Icons.favorite_rounded,
    route: '/health',
  ),
  home(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    route: '/home',
  ),
  wallet(
    label: AppStrings.navWallet,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    route: '/wallet',
  ),
  settings(
    label: AppStrings.navSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    route: '/settings',
  );

  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
