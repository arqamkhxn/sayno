import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_button.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../application/auth_service.dart';
import '../application/auth_exception_handler.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  String? _verificationId;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authServiceProvider).signInWithPhone(
        phoneNumber: phone,
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (message) {
          // Timeout
        },
        verificationFailed: (message) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: $message')),
          );
        },
        verificationCompleted: () async {
          // Auto-resolved
          setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthExceptionHandler.handleException(e))),
      );
    }
  }

  void _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _verificationId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authServiceProvider).verifyPhoneCode(_verificationId!, code);
      // Navigation is handled by authStateProvider listener in login_screen or router
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthExceptionHandler.handleException(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCodeSent = _verificationId != null;

    return SayNOScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.xl),
          Text(
            isCodeSent ? 'Enter Code' : 'Phone Login',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: AppSizes.xl),
          
          if (!isCodeSent) ...[
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (e.g. +1234567890)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSizes.xl),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SayNOButton(
                label: 'Send Code',
                onPressed: _sendCode,
              ),
          ] else ...[
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'SMS Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.xl),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SayNOButton(
                label: 'Verify Code',
                onPressed: _verifyCode,
              ),
          ]
        ],
      ),
    );
  }
}
