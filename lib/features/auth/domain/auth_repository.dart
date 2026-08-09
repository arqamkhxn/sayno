import 'user_session.dart';
import 'phone_auth_strategy.dart';

abstract class AuthRepository {
  Stream<UserSession?> get authStateChanges;
  UserSession? get currentUser;
  
  Future<void> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signOut();

  PhoneAuthStrategy get phoneAuthStrategy;
}
