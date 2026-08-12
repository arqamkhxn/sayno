import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/auth_provider.dart';
import '../domain/user_session.dart';
import '../domain/phone_auth_strategy.dart';
import 'firebase_phone_auth_strategy.dart';

class FirebaseAuthProvider implements AuthProvider {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebasePhoneAuthStrategy _phoneAuthStrategy = FirebasePhoneAuthStrategy();

  @override
  PhoneAuthStrategy get phoneAuthStrategy => _phoneAuthStrategy;

  UserSession? _mapUser(fb.User? user) {
    if (user == null) return null;
    return UserSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  @override
  Stream<UserSession?> get authStateChanges => 
    _firebaseAuth.authStateChanges().map(_mapUser);

  @override
  UserSession? get currentUser => _mapUser(_firebaseAuth.currentUser);

  Future<void> _createUserInFirestoreIfNeeded(fb.User? user) async {
    if (user == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'email': user.email,
          'displayName': user.displayName ?? user.phoneNumber ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Auth: Created new user document in Firestore for ${user.uid}');
      }
    } catch (e) {
      debugPrint('Auth Error: Failed to create user document in Firestore: $e');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      await _createUserInFirestoreIfNeeded(userCredential.user);
    } catch (e) {
      debugPrint('Auth Error: Google Sign-In failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      await _createUserInFirestoreIfNeeded(userCredential.user);
    } catch (e) {
      debugPrint('Auth Error: Email Sign-In failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      await _createUserInFirestoreIfNeeded(userCredential.user);
    } catch (e) {
      debugPrint('Auth Error: Email Sign-Up failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Auth Error: Sign-Out failed: $e');
      rethrow;
    }
  }
}
