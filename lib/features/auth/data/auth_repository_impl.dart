import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_provider.dart';
import '../domain/auth_repository.dart';
import '../domain/user_session.dart';
import '../domain/phone_auth_strategy.dart';
import 'firebase_auth_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(FirebaseAuthProvider());
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthProvider _provider;

  AuthRepositoryImpl(this._provider);

  @override
  Stream<UserSession?> get authStateChanges => _provider.authStateChanges;

  @override
  UserSession? get currentUser => _provider.currentUser;

  @override
  PhoneAuthStrategy get phoneAuthStrategy => _provider.phoneAuthStrategy;

  @override
  Future<void> signInWithGoogle() => _provider.signInWithGoogle();

  @override
  Future<void> signInWithEmail(String email, String password) => 
      _provider.signInWithEmail(email, password);

  @override
  Future<void> signUpWithEmail(String email, String password) => 
      _provider.signUpWithEmail(email, password);

  @override
  Future<void> signOut() => _provider.signOut();
}
