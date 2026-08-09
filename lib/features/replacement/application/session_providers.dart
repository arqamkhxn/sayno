import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/policies/replacement_session_policy.dart';
import '../data/repositories/session_repository_impl.dart';
import '../../../core/providers/shared_prefs_provider.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepositoryImpl(ref.watch(sharedPreferencesProvider));
});

final replacementSessionPolicyProvider = Provider<ReplacementSessionPolicy>((ref) {
  return DefaultReplacementSessionPolicy();
});
