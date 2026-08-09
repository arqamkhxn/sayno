abstract class PhoneAuthStrategy {
  Future<void> signInWithPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) codeAutoRetrievalTimeout,
    required void Function(String message) verificationFailed,
    required Future<void> Function() verificationCompleted,
  });

  Future<void> verifyPhoneCode(String verificationId, String smsCode);
}
