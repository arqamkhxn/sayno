import '../repositories/identity_repository.dart';

class SetUserIdentityUseCase {
  final IdentityRepository _repository;

  SetUserIdentityUseCase(this._repository);

  Future<void> execute(String identityId) async {
    await _repository.saveActiveIdentityId(identityId);
  }
}
