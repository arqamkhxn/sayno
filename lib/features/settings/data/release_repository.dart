import '../domain/release_request.dart';

abstract class ReleaseRepository {
  Future<void> createReleaseRequest(ReleaseRequest request);
  Future<ReleaseRequest?> getActiveReleaseRequest();
  Future<void> updateReleaseRequestStatus(int id, ReleaseStatus status);
  Future<void> updateReleaseRequest(ReleaseRequest request);
  Future<List<ReleaseRequest>> getReleaseHistory();
}
