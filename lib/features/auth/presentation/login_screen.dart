import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/guest_mode_provider.dart';
import '../application/auth_controller.dart';
import '../application/auth_exception_handler.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Tracks whether the screen is in Login or Sign Up mode.
final _authModeProvider = StateProvider<bool>((ref) => true); // true = login

/// Stores the pending username for sign-up (client-side).
final pendingUsernameProvider = StateProvider<String>((ref) => '');

/// Simple demo availability — cycles through states based on debounce.
enum UsernameStatus { idle, loading, available, taken }

final _usernameStatusProvider = StateProvider<UsernameStatus>((ref) => UsernameStatus.idle);

// ---------------------------------------------------------------------------
// Unified Auth Screen
// ---------------------------------------------------------------------------

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  Timer? _usernameDebounce;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _usernameDebounce?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _fadeController.reverse().then((_) {
      ref.read(_authModeProvider.notifier).state =
          !ref.read(_authModeProvider);
      ref.read(_usernameStatusProvider.notifier).state = UsernameStatus.idle;
      _usernameController.clear();
      _fadeController.forward();
    });
  }

  void _onUsernameChanged(String raw) {
    // Auto-format: lowercase, strip disallowed chars
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');

    if (cleaned != raw) {
      _usernameController
        ..text = cleaned
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: cleaned.length),
        );
    }

    ref.read(pendingUsernameProvider.notifier).state = cleaned;
    ref.read(_usernameStatusProvider.notifier).state = UsernameStatus.idle;

    _usernameDebounce?.cancel();
    if (cleaned.isEmpty) return;

    ref.read(_usernameStatusProvider.notifier).state = UsernameStatus.loading;
    _usernameDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      // Demo: usernames ending in odd digit are "taken"
      final taken = cleaned.isNotEmpty &&
          cleaned.runes.last >= '1'.codeUnitAt(0) &&
          cleaned.runes.last <= '9'.codeUnitAt(0) &&
          (cleaned.runes.last - '0'.codeUnitAt(0)).isOdd;
      ref.read(_usernameStatusProvider.notifier).state =
          taken ? UsernameStatus.taken : UsernameStatus.available;
    });
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    final isLogin = ref.read(_authModeProvider);
    if (isLogin) {
      ref.read(authControllerProvider.notifier).signInWithEmail(email, password);
    } else {
      _signUpAndClaim(email, password);
    }
  }

  /// Two-step sign-up flow:
  ///   1. Create the Firebase account.
  ///   2. If a username was entered (and is available), claim it.
  Future<void> _signUpAndClaim(String email, String password) async {
    await ref.read(authControllerProvider.notifier).signUpWithEmail(email, password);

    // Only attempt claim if account creation succeeded and a handle was entered
    final handle = ref.read(pendingUsernameProvider);
    final status = ref.read(_usernameStatusProvider);
    if (handle.isEmpty || status != UsernameStatus.available) return;

    final result = await ref
        .read(authControllerProvider.notifier)
        .claimUsername(handle);

    if (!mounted) return;

    final message = switch (result) {
      UsernameClaimResult.success => '@$handle is yours!',
      UsernameClaimResult.handleTaken => '@$handle was just taken. You can set it later in Settings.',
      UsernameClaimResult.invalidHandle => 'Username format is invalid. You can set it later in Settings.',
      UsernameClaimResult.alreadyHasUsername => 'You already have a username.',
      UsernameClaimResult.networkError => 'Username could not be saved. You can set it later in Settings.',
    };
    final isSuccess = result == UsernameClaimResult.success;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = ref.watch(_authModeProvider);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthExceptionHandler.handleException(next.error)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenPadding,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSizes.xxl),
                _buildBrandHeader(),
                const SizedBox(height: AppSizes.xxl),
                _buildModeToggle(isLogin),
                const SizedBox(height: AppSizes.lg),
                _buildEmailForm(isLogin, isLoading),
                const SizedBox(height: AppSizes.md),
                if (!isLogin) ...[
                  _buildUsernameField(),
                  const SizedBox(height: AppSizes.md),
                ],
                _buildSubmitButton(isLogin, isLoading),
                const SizedBox(height: AppSizes.lg),
                _buildDivider(),
                const SizedBox(height: AppSizes.lg),
                _buildGoogleButton(isLoading),
                const SizedBox(height: AppSizes.xxl),
                _buildFooterToggle(isLogin),
                const SizedBox(height: AppSizes.lg),
                _buildGuestButton(),
                const SizedBox(height: AppSizes.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Logo mark
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          child: const Center(
            child: Text(
              'SN',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.background,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          'SAYNO',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Own your attention. Reclaim your life.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildModeToggle(bool isLogin) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          _toggleTab(label: 'Sign In', selected: isLogin, onTap: () {
            if (!isLogin) _toggleMode();
          }),
          _toggleTab(label: 'Sign Up', selected: !isLogin, onTap: () {
            if (isLogin) _toggleMode();
          }),
        ],
      ),
    );
  }

  Widget _toggleTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.background : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(bool isLogin, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !isLoading,
          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
        ),
        const SizedBox(height: AppSizes.sm),
        _buildTextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          enabled: !isLoading,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (isLogin) ...[
          const SizedBox(height: AppSizes.sm),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              // Forgot password — stub for now
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool enabled = true,
    Widget? suffix,
    Widget? prefix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: enabled,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: onSubmitted != null ? TextInputAction.next : TextInputAction.done,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.textDisabled,
          ),
          prefixIcon: prefix ?? Icon(icon, color: AppColors.textSecondary, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    final status = ref.watch(_usernameStatusProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _usernameController,
          hint: 'username',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.text,
          onChanged: _onUsernameChanged,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Text(
              '@',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildUsernameStatusIcon(status),
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        _buildUsernameStatusLabel(status),
      ],
    );
  }

  Widget _buildUsernameStatusIcon(UsernameStatus status) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (status) {
        UsernameStatus.idle => const SizedBox.shrink(key: ValueKey('idle')),
        UsernameStatus.loading => const SizedBox(
            key: ValueKey('loading'),
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textSecondary,
            ),
          ),
        UsernameStatus.available => const Icon(
            key: ValueKey('available'),
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 20,
          ),
        UsernameStatus.taken => const Icon(
            key: ValueKey('taken'),
            Icons.cancel_rounded,
            color: AppColors.danger,
            size: 20,
          ),
      },
    );
  }

  Widget _buildUsernameStatusLabel(UsernameStatus status) {
    final username = ref.watch(pendingUsernameProvider);
    if (status == UsernameStatus.idle || username.isEmpty) {
      return Text(
        'Only letters a–z, numbers, underscores and dots',
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDisabled),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (status) {
        UsernameStatus.loading => Text(
            'Checking @$username...',
            key: const ValueKey('loading'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
        UsernameStatus.available => Text(
            '@$username is available ✓',
            key: const ValueKey('available'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.success,
            ),
          ),
        UsernameStatus.taken => Text(
            '@$username is already taken',
            key: const ValueKey('taken'),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.danger,
            ),
          ),
        UsernameStatus.idle => const SizedBox.shrink(key: ValueKey('idle2')),
      },
    );
  }

  Widget _buildSubmitButton(bool isLogin, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: isLoading
              ? AppColors.textPrimary.withValues(alpha: 0.5)
              : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.background,
                  ),
                )
              : Text(
                  isLogin ? 'Sign In' : 'Create Account',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.background,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.surfaceBorder, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(
            'or continue with',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.surfaceBorder, height: 1)),
      ],
    );
  }

  Widget _buildGoogleButton(bool isLoading) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google 'G' logo rendered with coloured text segments
            _GoogleLogo(size: 20),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterToggle(bool isLogin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? "Don't have an account? " : 'Already have an account? ',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: _toggleMode,
          child: Text(
            isLogin ? 'Sign Up' : 'Sign In',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestButton() {
    return GestureDetector(
      onTap: () {
        ref.read(guestModeProvider.notifier).setGuestMode(true);
      },
      child: Center(
        child: Text(
          'Continue as Guest',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google "G" logo widget (pure Flutter, no image asset needed)
// ---------------------------------------------------------------------------

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Draw arc segments (simplified Google G)
    final paint = Paint()..strokeWidth = size.width * 0.15 ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round;

    // Blue top-right arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85), -1.1, 1.9, false, paint);

    // Red bottom-left arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85), 0.8, 1.5, false, paint);

    // Yellow bottom arc
    paint.color = const Color(0xFFFBBC04);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85), 2.3, 0.9, false, paint);

    // Green top-left arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85), -1.9, 0.8, false, paint);

    // Horizontal bar of the G
    paint
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
    canvas.drawRect(
      Rect.fromLTWH(cx - 0.05, cy - size.height * 0.12, r * 0.9, size.height * 0.24),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
