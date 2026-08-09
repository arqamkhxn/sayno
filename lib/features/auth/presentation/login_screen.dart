import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('UI: LoginScreen build() called');
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${next.error}')),
        );
      }
    });

    return SayNOScaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign In / Create Account',
            style: AppTextStyles.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Your account is automatically created the first time you sign in.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.xxxl),
          
          if (authState.isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            SayNOButton(
              label: 'Continue with Google',
              icon: Icons.g_mobiledata_rounded,
              onPressed: () {
                debugPrint('UI: LoginScreen Google button pressed');
                ref.read(authControllerProvider.notifier).signInWithGoogle();
              },
            ),
            const SizedBox(height: AppSizes.md),
            SayNOButton(
              label: 'Continue with Email',
              icon: Icons.email_outlined,
              variant: SayNOButtonVariant.secondary,
              onPressed: () => context.push('/login/email'),
            ),
            const SizedBox(height: AppSizes.md),
            SayNOButton(
              label: 'Continue with Phone',
              icon: Icons.phone_android_rounded,
              variant: SayNOButtonVariant.secondary,
              onPressed: () => context.push('/login/phone'),
            ),
          ],
        ],
      ),
    );
  }
}
