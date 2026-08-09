import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../domain/phone_auth_strategy.dart';

class FirebasePhoneAuthStrategy implements PhoneAuthStrategy {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  Future<void> _createUserInFirestoreIfNeeded(fb.User? user) async {
    if (user == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'email': user.email,
          'displayName': user.phoneNumber ?? 'User',
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
  Future<void> signInWithPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) codeAutoRetrievalTimeout,
    required void Function(String message) verificationFailed,
    required Future<void> Function() verificationCompleted,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          final userCredential = await _firebaseAuth.signInWithCredential(credential);
          await _createUserInFirestoreIfNeeded(userCredential.user);
          await verificationCompleted();
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          debugPrint('Auth Error: Phone verification failed: ${e.message}');
          verificationFailed(e.message ?? 'Verification failed');
        },
        codeSent: codeSent,
        codeAutoRetrievalTimeout: (String verificationId) {
          codeAutoRetrievalTimeout('Code auto-retrieval timeout');
        },
      );
    } catch (e) {
      debugPrint('Auth Error: verifyPhoneNumber threw exception: $e');
      rethrow;
    }
  }

  @override
  Future<void> verifyPhoneCode(String verificationId, String smsCode) async {
    try {
      final fb.PhoneAuthCredential credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      await _createUserInFirestoreIfNeeded(userCredential.user);
    } catch (e) {
      debugPrint('Auth Error: verifyPhoneCode failed: $e');
      rethrow;
    }
  }
}
