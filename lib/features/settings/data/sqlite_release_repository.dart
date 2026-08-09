import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/data/session_database.dart';
import '../domain/release_request.dart';
import 'release_repository.dart';

final releaseRepositoryProvider = Provider<ReleaseRepository>((ref) {
  final db = ref.watch(sessionDatabaseProvider);
  return SqliteReleaseRepository(db);
});

class SqliteReleaseRepository implements ReleaseRepository {
  final SessionDatabase _database;

  SqliteReleaseRepository(this._database);

  @override
  Future<void> createReleaseRequest(ReleaseRequest request) async {
    final db = await _database.database;
    await db.insert('release_requests', request.toMap());
  }

  @override
  Future<ReleaseRequest?> getActiveReleaseRequest() async {
    final db = await _database.database;
    final results = await db.query(
      'release_requests',
      where: 'status = ? OR status = ? OR status = ?',
      whereArgs: [
        ReleaseStatus.cooldown.name,
        ReleaseStatus.pending_approval.name,
        ReleaseStatus.grace_window.name,
      ],
      orderBy: 'requested_at_utc DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ReleaseRequest.fromMap(results.first);
  }

  @override
  Future<void> updateReleaseRequestStatus(int id, ReleaseStatus status) async {
    final db = await _database.database;
    await db.update(
      'release_requests',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateReleaseRequest(ReleaseRequest request) async {
    final db = await _database.database;
    await db.update(
      'release_requests',
      request.toMap(),
      where: 'id = ?',
      whereArgs: [request.id],
    );
  }

  @override
  Future<List<ReleaseRequest>> getReleaseHistory() async {
    final db = await _database.database;
    final results = await db.query(
      'release_requests',
      orderBy: 'requested_at_utc DESC',
    );
    return results.map((map) => ReleaseRequest.fromMap(map)).toList();
  }
}
