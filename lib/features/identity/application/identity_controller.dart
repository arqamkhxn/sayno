import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/identity_configuration.dart';
import '../domain/user_identity.dart';
import '../domain/identity_repository.dart';
import '../data/local_identity_data_source.dart';
import '../data/identity_repository_impl.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return IdentityRepositoryImpl(LocalIdentityDataSource());
});

final identityControllerProvider = AsyncNotifierProvider<IdentityController, IdentityConfiguration?>(
  () => IdentityController(),
);

class IdentityController extends AsyncNotifier<IdentityConfiguration?> {
  @override
  Future<IdentityConfiguration?> build() async {
    debugPrint('PROVIDER: IdentityController build() called');
    final repo = ref.watch(identityRepositoryProvider);
    final config = await repo.getActiveConfiguration();
    debugPrint('PROVIDER: IdentityController loaded config: ${config?.id}');
    return config;
  }

  Future<void> saveIdentities(List<UserIdentity> identities) async {
    final repo = ref.read(identityRepositoryProvider);
    
    final newConfig = IdentityConfiguration(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      isActive: true,
      identities: identities,
    );

    await repo.saveConfiguration(newConfig);
    state = AsyncData(newConfig);
  }

  Future<void> clearIdentity() async {
    final repo = ref.read(identityRepositoryProvider);
    await repo.clearAll();
    state = const AsyncData(null);
  }
}
