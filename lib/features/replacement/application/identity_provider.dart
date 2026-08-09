import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/identity_repository.dart';
import '../data/repositories/identity_repository_impl.dart';
import '../../../core/providers/shared_prefs_provider.dart';
import '../domain/entities/user_identity.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return IdentityRepositoryImpl(prefs);
});

final activeIdentityProvider = AsyncNotifierProvider<ActiveIdentity, UserIdentity?>(() {
  return ActiveIdentity();
});

class ActiveIdentity extends AsyncNotifier<UserIdentity?> {
  @override
  FutureOr<UserIdentity?> build() async {
    final repository = ref.watch(identityRepositoryProvider);
    final identityId = await repository.getActiveIdentityId();
    if (identityId == null) return null;
    
    final identities = await repository.getAvailableIdentities();
    try {
      return identities.firstWhere((i) => i.id == identityId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setIdentity(String identityId) async {
    final repository = ref.watch(identityRepositoryProvider);
    await repository.saveActiveIdentityId(identityId);
    ref.invalidateSelf();
  }
}
