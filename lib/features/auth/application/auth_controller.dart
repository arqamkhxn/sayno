import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/user_session.dart';
import '../data/auth_repository_impl.dart';
import 'auth_service.dart';
import '../../identity/application/identity_controller.dart';

/// Base URL for the sayno-uce API.
/// Reads from compile-time env (dart-define); defaults to localhost for dev.
const String _kApiBaseUrl = String.fromEnvironment(
  'UCE_API_URL',
  defaultValue: 'http://localhost:3000',
);

// =============================================================================
// Auth State Providers
// =============================================================================

final authStateProvider = StreamProvider<UserSession?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final usernameProvider = StreamProvider<String?>((ref) {
  final session = ref.watch(authStateProvider).value;
  if (session == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(session.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        final data = doc.data();
        return data?['username'] as String?;
      });
});

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.read(authServiceProvider), ref);
});

// =============================================================================
// Username Claim Result
// =============================================================================

/// Result of a username claim attempt — enables the UI to show specific feedback.
enum UsernameClaimResult {
  success,
  handleTaken,
  invalidHandle,
  alreadyHasUsername,
  networkError,
}

/// Provider for the most recent username claim result (separate from general auth loading).
final usernameClaimResultProvider = StateProvider<UsernameClaimResult?>((ref) => null);

// =============================================================================
// AuthController
// =============================================================================

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final Ref _ref;

  AuthController(this._authService, this._ref) : super(const AsyncData(null));

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _authService.signInWithGoogle();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authService.signInWithEmail(email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authService.signUpWithEmail(email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Atomically claims the given @handle via the sayno-uce API.
  ///
  /// Flow:
  ///   1. Fetch the current Firebase ID token (refreshed automatically).
  ///   2. POST /v1/username/claim with Bearer token.
  ///   3. Parse the response into a [UsernameClaimResult] and write to
  ///      [usernameClaimResultProvider] for the UI to react to.
  ///
  /// Does NOT set the main [authControllerProvider] loading state — the
  /// username claim is a secondary, non-blocking step in the sign-up flow.
  Future<UsernameClaimResult> claimUsername(String handle) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        return UsernameClaimResult.networkError;
      }

      final uri = Uri.parse('$_kApiBaseUrl/v1/username/claim');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'handle': handle}),
      );

      final UsernameClaimResult result = switch (response.statusCode) {
        201 => UsernameClaimResult.success,
        400 => UsernameClaimResult.invalidHandle,
        409 => UsernameClaimResult.handleTaken,
        422 => UsernameClaimResult.alreadyHasUsername,
        _ => UsernameClaimResult.networkError,
      };

      debugPrint('Auth: claimUsername "@$handle" → HTTP ${response.statusCode} → $result');
      _ref.read(usernameClaimResultProvider.notifier).state = result;
      return result;
    } catch (e) {
      debugPrint('Auth: claimUsername network error: $e');
      _ref.read(usernameClaimResultProvider.notifier).state = UsernameClaimResult.networkError;
      return UsernameClaimResult.networkError;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _ref.read(identityControllerProvider.notifier).clearIdentity();
      await _authService.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
