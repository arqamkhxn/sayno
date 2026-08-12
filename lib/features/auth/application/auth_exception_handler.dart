import 'package:firebase_auth/firebase_auth.dart';

class AuthExceptionHandler {
  static String handleException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'The email address is badly formatted.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-credential':
          return 'Invalid credentials provided. Please check your inputs.';
        case 'invalid-verification-code':
          return 'The verification code is invalid.';
        case 'invalid-verification-id':
          return 'The verification session is invalid or has expired.';
        case 'quota-exceeded':
          return 'Too many requests. Please try again later.';
        default:
          return 'An authentication error occurred: ${e.message}';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
