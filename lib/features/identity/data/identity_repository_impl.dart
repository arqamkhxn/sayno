import '../domain/identity_configuration.dart';
import '../domain/identity_repository.dart';
import 'local_identity_data_source.dart';

class IdentityRepositoryImpl implements IdentityRepository {
  final LocalIdentityDataSource _localDataSource;

  IdentityRepositoryImpl(this._localDataSource);

  @override
  Future<IdentityConfiguration?> getActiveConfiguration() {
    return _localDataSource.getActiveConfiguration();
  }

  @override
  Future<void> saveConfiguration(IdentityConfiguration config) async {
    await _localDataSource.saveConfiguration(config);
    // Future: Dispatch to RemoteIdentityDataSource here
  }
}
