import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/partnership_repository.dart';
import '../data/sqlite_partnership_repository.dart';
import '../domain/partnership.dart';

/// Provider to track whether Firebase was successfully initialized on startup.
/// Overridden in main.dart if Firebase initialization succeeds.
final firebaseInitializedProvider = Provider<bool>((ref) => false);

/// State class for PartnerController.
class PartnerState {
  final Partnership? partnership;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const PartnerState({
    this.partnership,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  PartnerState copyWith({
    Partnership? partnership,
    bool clearPartnership = false,
    bool isLoading = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
  }) {
    return PartnerState(
      partnership: clearPartnership ? null : (partnership ?? this.partnership),
      isLoading: isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Provider for PartnerController state management.
final partnerControllerProvider =
    StateNotifierProvider<PartnerController, PartnerState>((ref) {
  final repository = ref.watch(partnershipRepositoryProvider);
  return PartnerController(repository, ref);
});

class PartnerController extends StateNotifier<PartnerState> {
  final PartnershipRepository _repository;
  final Ref ref;

  PartnerController(this._repository, this.ref) : super(const PartnerState()) {
    _init();
  }

  void _init() {
    loadPartnership();
    
    // Listen to Firebase Authentication state changes if Firebase is initialized.
    final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
    if (isFirebaseInitialized) {
      try {
        FirebaseAuth.instance.authStateChanges().listen((user) {
          loadPartnership();
        });
      } catch (e) {
        debugPrint('Error listening to auth changes: $e');
      }
    }
  }

  /// Loads the partnership status from local database and syncs with Firestore if available.
  Future<void> loadPartnership() async {
    final local = await _repository.getLocalPartnership();
    state = state.copyWith(partnership: local);

    final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
    if (isFirebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final synced = await _repository.syncPartnership(user.uid);
          state = state.copyWith(partnership: synced);
        }
      } catch (e) {
        debugPrint('Error syncing partnership with Firestore: $e');
      }
    }
  }

  /// Generates a secure random 8-character verification token.
  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  /// Invites a partner by email.
  Future<void> invitePartner(String partnerEmail) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true, clearSuccessMessage: true);
    
    final trimmedEmail = partnerEmail.toLowerCase().trim();
    if (trimmedEmail.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Email address cannot be empty.',
      );
      return;
    }

    try {
      final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
      if (!isFirebaseInitialized) {
        throw Exception('Accountability features are currently unavailable.');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to invite a partner.');
      }

      if (user.email == null) {
        throw Exception('Your account does not have a verified email address.');
      }

      if (user.email!.toLowerCase().trim() == trimmedEmail) {
        throw Exception('You cannot invite your own email address.');
      }

      final token = _generateToken();
      await _repository.invitePartner(
        userEmail: user.email!,
        userId: user.uid,
        partnerEmail: trimmedEmail,
        verificationToken: token,
      );

      final local = await _repository.getLocalPartnership();
      state = state.copyWith(
        partnership: local,
        isLoading: false,
        successMessage: 'Invitation sent successfully! Token: $token',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Accepts an invitation with the verification token and partner email.
  Future<void> acceptInvitation(String token, String partnerEmail) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true, clearSuccessMessage: true);

    final trimmedToken = token.toUpperCase().trim();
    final trimmedEmail = partnerEmail.toLowerCase().trim();

    if (trimmedToken.isEmpty || trimmedEmail.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Token and partner email are required.',
      );
      return;
    }

    try {
      final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
      if (!isFirebaseInitialized) {
        throw Exception('Accountability features are currently unavailable.');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to accept an invitation.');
      }

      if (user.email != null && user.email!.toLowerCase().trim() == trimmedEmail) {
        throw Exception('Self-linking is not allowed.');
      }

      await _repository.acceptInvitation(
        token: trimmedToken,
        partnerEmail: trimmedEmail,
        partnerUid: user.uid,
      );

      final local = await _repository.getLocalPartnership();
      state = state.copyWith(
        partnership: local,
        isLoading: false,
        successMessage: 'Accountability partner linked successfully!',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Authenticates using email and password.
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true, clearSuccessMessage: true);
    try {
      final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
      if (!isFirebaseInitialized) {
        throw Exception('Accountability features are currently unavailable.');
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await loadPartnership();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Registers a new account using email and password.
  Future<void> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true, clearSuccessMessage: true);
    try {
      final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
      if (!isFirebaseInitialized) {
        throw Exception('Accountability features are currently unavailable.');
      }

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await loadPartnership();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Account created and signed in!',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Signs out of Firebase and clears local partnership.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true, clearSuccessMessage: true);
    try {
      final isFirebaseInitialized = ref.read(firebaseInitializedProvider);
      if (isFirebaseInitialized) {
        await FirebaseAuth.instance.signOut();
      }
      await _repository.clearLocalPartnership();
      state = state.copyWith(
        partnership: null,
        clearPartnership: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Clears any outstanding success or error messages.
  void clearMessages() {
    state = state.copyWith(clearErrorMessage: true, clearSuccessMessage: true);
  }
}
