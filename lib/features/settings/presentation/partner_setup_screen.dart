import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/partner_controller.dart';
import '../domain/partnership.dart';

class PartnerSetupScreen extends ConsumerStatefulWidget {
  const PartnerSetupScreen({super.key});

  @override
  ConsumerState<PartnerSetupScreen> createState() => _PartnerSetupScreenState();
}

class _PartnerSetupScreenState extends ConsumerState<PartnerSetupScreen> {
  // Auth Form State
  bool _isLoginTab = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Invite Form State
  final _inviteEmailController = TextEditingController();

  // Accept Form State
  final _acceptEmailController = TextEditingController();
  final _acceptTokenController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _inviteEmailController.dispose();
    _acceptEmailController.dispose();
    _acceptTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirebaseInitialized = ref.watch(firebaseInitializedProvider);
    final partnerState = ref.watch(partnerControllerProvider);
    final currentUser = isFirebaseInitialized ? FirebaseAuth.instance.currentUser : null;

    return SayNOScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.lg),
          // Custom Header with Back Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                'Accountability Partner',
                style: AppTextStyles.headlineLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),

          // Render Success / Error messages as status banners
          if (partnerState.errorMessage != null) ...[
            _buildStatusBanner(
              message: partnerState.errorMessage!,
              color: AppColors.danger,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: AppSizes.md),
          ],
          if (partnerState.successMessage != null) ...[
            _buildStatusBanner(
              message: partnerState.successMessage!,
              color: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: AppSizes.md),
          ],

          if (!isFirebaseInitialized) ...[
            // 1. Firebase Unavailable state card
            _buildUnavailableCard(),
          ] else if (currentUser == null) ...[
            // 2. Auth forms (Sign In / Register)
            _buildAuthSection(partnerState.isLoading),
          ] else ...[
            // 3. Authenticated - display linking dashboard
            _buildDashboard(partnerState, currentUser),
          ],
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: color),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: color, size: AppSizes.iconSm),
            onPressed: () {
              ref.read(partnerControllerProvider.notifier).clearMessages();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.danger.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: AppSizes.iconXl),
              SizedBox(width: AppSizes.md),
              Expanded(
                child: Text(
                  'Accountability Unavailable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Firebase is not configured or failed to initialize on this device. '
            'Interpersonal accountability features (invitations, synchronization, and verification) are disabled. '
            'Please verify google-services.json configuration.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthSection(bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect Cloud Sync',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'An account is required to sync progress and link your accountability partner securely.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.lg),
          // Tabs
          Row(
            children: [
              _buildTabButton('Sign In', _isLoginTab, () {
                setState(() => _isLoginTab = true);
              }),
              const SizedBox(width: AppSizes.md),
              _buildTabButton('Create Account', !_isLoginTab, () {
                setState(() => _isLoginTab = false);
              }),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          // Form
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          SayNOButton(
            label: _isLoginTab ? 'Sign In' : 'Sign Up',
            isLoading: isLoading,
            onPressed: () {
              final notifier = ref.read(partnerControllerProvider.notifier);
              if (_isLoginTab) {
                notifier.signIn(_emailController.text, _passwordController.text);
              } else {
                notifier.signUp(_emailController.text, _passwordController.text);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.sm),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceElevated : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: isActive ? AppColors.surfaceBorder : AppColors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(PartnerState state, User user) {
    final partnership = state.partnership;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User status card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary, size: AppSizes.iconLg),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signed in as', style: AppTextStyles.bodySmall),
                    Text(user.email ?? 'No email', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TextButton.icon(
                label: const Text('Sign Out'),
                icon: const Icon(Icons.logout_rounded, size: 16),
                onPressed: () {
                  ref.read(partnerControllerProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        if (partnership == null) ...[
          // Option A: Send invitation
          _buildInviteCard(state.isLoading),
          const SizedBox(height: AppSizes.lg),
          // Option B: Enter verification token (Accept invitation)
          _buildAcceptCard(state.isLoading),
        ] else if (partnership.status == PartnershipStatus.pending) ...[
          _buildPendingCard(partnership, state.isLoading),
        ] else if (partnership.status == PartnershipStatus.active) ...[
          _buildActiveCard(partnership, state.isLoading),
        ],
      ],
    );
  }

  Widget _buildInviteCard(bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.send_rounded, color: AppColors.accent, size: AppSizes.iconXl),
          const SizedBox(height: AppSizes.md),
          Text('Invite a Partner', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Invite your accountability partner by entering their email address. They will need to verify using the link token.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.lg),
          TextField(
            controller: _inviteEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "Partner's email address",
              prefixIcon: Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          SayNOButton(
            label: 'Send Invitation',
            isLoading: isLoading,
            onPressed: () {
              ref
                  .read(partnerControllerProvider.notifier)
                  .invitePartner(_inviteEmailController.text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptCard(bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key_rounded, color: AppColors.accent, size: AppSizes.iconXl),
          const SizedBox(height: AppSizes.md),
          Text('Enter Invitation Token', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSizes.sm),
          Text(
            'If someone has invited you to be their partner, enter their email address and the 8-character verification token below.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.lg),
          TextField(
            controller: _acceptEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "Inviter's email address",
              prefixIcon: Icon(Icons.person_pin_outlined),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _acceptTokenController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: '8-Character Verification Token (e.g. 5X8R2NPL)',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          SayNOButton(
            label: 'Verify and Link Partner',
            isLoading: isLoading,
            onPressed: () {
              ref.read(partnerControllerProvider.notifier).acceptInvitation(
                    _acceptTokenController.text,
                    _acceptEmailController.text,
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Partnership partnership, bool isLoading) {
    // Extract token from success message if available, or just display pending state
    final successMsg = ref.read(partnerControllerProvider).successMessage;
    final tokenRegExp = RegExp(r'Token:\s*([A-Z0-9]{8})');
    final match = successMsg != null ? tokenRegExp.firstMatch(successMsg) : null;
    final token = match?.group(1) ?? 'PENDING';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: AppColors.warning, size: AppSizes.iconXl),
              const SizedBox(width: AppSizes.md),
              Text('Invitation Pending', style: AppTextStyles.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              children: [
                const TextSpan(text: 'You have invited '),
                TextSpan(
                  text: partnership.partnerEmail,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const TextSpan(text: ' to be your accountability partner.'),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          if (token != 'PENDING') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  Text('SHARE VERIFICATION TOKEN', style: AppTextStyles.labelSmall),
                  const SizedBox(height: AppSizes.sm),
                  SelectableText(
                    token,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  TextButton.icon(
                    label: const Text('Copy to Clipboard'),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification token copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
          SayNOButton(
            label: 'Cancel Invitation',
            variant: SayNOButtonVariant.danger,
            isLoading: isLoading,
            onPressed: () {
              ref.read(partnerControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(Partnership partnership, bool isLoading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: AppSizes.iconLg),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accountability Active', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      'Linked Partner: ${partnership.partnerEmail}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'Your device protection status is fully supervised. Release requests will require verification by your partner before completion.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.xl),
          SayNOButton(
            label: 'Unlink Accountability Partner',
            variant: SayNOButtonVariant.secondary,
            isLoading: isLoading,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Unlink Partner?'),
                  content: const Text(
                    'Are you sure you want to unlink your accountability partner? '
                    'This will remove synchronization settings and local caches.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(partnerControllerProvider.notifier).signOut();
                      },
                      child: const Text('Unlink'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
