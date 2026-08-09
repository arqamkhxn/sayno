import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../contract/application/contract_controller.dart';
import '../application/release_controller.dart';
import '../domain/release_request.dart';
import '../application/partner_controller.dart';
import '../domain/partnership.dart';
import '../../auth/application/auth_controller.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../../protection/application/protection_controller.dart';
import '../../protection/domain/protection_status.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _shouldRefreshProtectionOnResume = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_shouldRefreshProtectionOnResume) {
      return;
    }

    _shouldRefreshProtectionOnResume = false;
    ref.read(protectionControllerProvider.notifier).refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final activeContract = ref.watch(activeContractProvider).value;
    final releaseState = ref.watch(releaseControllerProvider);
    final partnerState = ref.watch(partnerControllerProvider);
    final authState = ref.watch(authStateProvider).value;

    final partnerSubtitle = partnerState.partnership == null
        ? 'Not configured'
        : (partnerState.partnership!.status == PartnershipStatus.active
            ? 'Linked: ${partnerState.partnership!.partnerEmail}'
            : 'Pending invitation');

    // Redirect to the cooldown screen if a cooldown, pending approval, or grace window is active
    if (releaseState.activeRequest != null &&
        (releaseState.activeRequest!.status == ReleaseStatus.cooldown ||
         releaseState.activeRequest!.status == ReleaseStatus.pending_approval ||
         releaseState.activeRequest!.status == ReleaseStatus.grace_window) &&
        !releaseState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/release-cooldown');
      });
    }

    final protectionStatus = ref.watch(protectionControllerProvider).when(
          data: (status) => status,
          error: (_, __) => ProtectionStatus.unknown,
          loading: () => ProtectionStatus.unknown,
        );
    final isProtected = protectionStatus == ProtectionStatus.protected;

    return SayNOScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.lg),
          Text(AppStrings.settingsTitle, style: AppTextStyles.headlineLarge),
          const SizedBox(height: AppSizes.xxl),
          SettingsSection(
            title: AppStrings.sectionProtection,
            children: [
              SettingsTile(
                title: 'Enable Protection',
                subtitle: isProtected
                    ? 'Accessibility protection is enabled'
                    : 'Accessibility Service is required',
                leading: Icons.shield_rounded,
                trailing: protectionStatus.displayLabel,
                showArrow: false,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: SayNOButton(
                  label: 'Open Accessibility Settings',
                  icon: Icons.open_in_new_rounded,
                  variant: SayNOButtonVariant.secondary,
                  onPressed: () async {
                    _shouldRefreshProtectionOnResume = true;
                    await ref
                        .read(protectionControllerProvider.notifier)
                        .openAccessibilitySettings();
                  },
                ),
              ),
              SettingsTile(
                title: AppStrings.blockedApps,
                subtitle: '3 apps restricted',
                leading: Icons.apps_rounded,
                onTap: () {},
              ),
              SettingsTile(
                title: AppStrings.usageLimits,
                subtitle: '2h daily limit',
                leading: Icons.timer_outlined,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          SettingsSection(
            title: AppStrings.sectionAccount,
            children: [
              SettingsTile(
                title: AppStrings.accountabilityPartner,
                subtitle: partnerSubtitle,
                leading: Icons.people_outline_rounded,
                onTap: () => context.push('/partner-setup'),
              ),
              SettingsTile(
                title: AppStrings.notifications,
                leading: Icons.notifications_none_rounded,
                isToggle: true,
                toggleValue: _notificationsEnabled,
                onToggleChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
                showArrow: false,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          SettingsSection(
            title: AppStrings.sectionAppearance,
            children: [
              const SettingsTile(
                title: AppStrings.appVersion,
                trailing: '1.0.0',
                leading: Icons.info_outline_rounded,
                showArrow: false,
              ),
              SettingsTile(
                title: AppStrings.privacyPolicy,
                leading: Icons.privacy_tip_outlined,
                onTap: () {},
              ),
              SettingsTile(
                title: AppStrings.termsOfService,
                leading: Icons.description_outlined,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          SettingsSection(
            title: AppStrings.sectionDanger,
            children: [
              if (activeContract != null) ...[
                if (releaseState.activeRequest?.status == ReleaseStatus.completed)
                  SettingsTile(
                    title: 'Deactivation Status',
                    subtitle: 'Release Authorized',
                    leading: Icons.check_circle_rounded,
                    trailing: 'Authorized',
                    titleColor: AppColors.success,
                    onTap: () {
                      context.go('/release-cooldown');
                    },
                  )
                else
                  SettingsTile(
                    title: 'Request Release',
                    subtitle: 'Initiate deactivation cooldown',
                    leading: Icons.lock_open_rounded,
                    titleColor: AppColors.warning,
                    onTap: () => _showRequestReleaseDialog(context, ref),
                  ),
              ],
              if (authState != null)
                SettingsTile(
                  title: AppStrings.signOut,
                  leading: Icons.logout_rounded,
                  titleColor: AppColors.warning,
                  onTap: () {
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                )
              else
                SettingsTile(
                  title: 'Login',
                  leading: Icons.login_rounded,
                  titleColor: Colors.white,
                  onTap: () {
                    context.push('/login');
                  },
                ),
              if (authState != null)
                SettingsTile(
                  title: 'Manage Identity',
                  leading: Icons.person_outline_rounded,
                  titleColor: Colors.white,
                  onTap: () {
                    context.push('/identity/select');
                  },
                ),
              SettingsTile(
                title: AppStrings.deleteAccount,
                leading: Icons.delete_outline_rounded,
                titleColor: AppColors.danger,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }

  void _showRequestReleaseDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request Deactivation?'),
          content: const Text(
            'Deactivating protection requires a cooldown period before it takes effect. '
            'Warning shields and Settings locks remain fully active during this time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(releaseControllerProvider.notifier).initiateRelease(durationSeconds: 60);
              },
              child: const Text('1-Min Cooldown (Testing)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(releaseControllerProvider.notifier).initiateRelease(durationSeconds: 86400);
              },
              child: const Text('Start 24-Hour Cooldown'),
            ),
          ],
        );
      },
    );
  }
}
