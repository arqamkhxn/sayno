import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(authRepositoryProvider));
});

class AuthService {
  final AuthRepository _repository;

  AuthService(this._repository);

  Future<void> signInWithGoogle() async {
    await _repository.signInWithGoogle();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _repository.signInWithEmail(email, password);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _repository.signUpWithEmail(email, password);
  }

  Future<void> signInWithPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) codeAutoRetrievalTimeout,
    required void Function(String message) verificationFailed,
    required Future<void> Function() verificationCompleted,
  }) async {
    await _repository.phoneAuthStrategy.signInWithPhone(
      phoneNumber: phoneNumber,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      verificationFailed: verificationFailed,
      verificationCompleted: verificationCompleted,
    );
  }

  Future<void> verifyPhoneCode(String verificationId, String smsCode) async {
    await _repository.phoneAuthStrategy.verifyPhoneCode(verificationId, smsCode);
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }
}
