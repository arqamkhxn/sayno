import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_identity.dart';
import '../../domain/repositories/identity_repository.dart';

class IdentityRepositoryImpl implements IdentityRepository {
  static const _keyIdentityId = 'user_identity_id';
  
  final SharedPreferences _prefs;

  IdentityRepositoryImpl(this._prefs);

  @override
  Future<String?> getActiveIdentityId() async {
    return _prefs.getString(_keyIdentityId);
  }

  @override
  Future<List<UserIdentity>> getAvailableIdentities() async {
    // In a real app, this might come from a remote source or local config.
    // For now, we return a hardcoded list matching the default catalog.
    return const [
      UserIdentity(
        id: 'entrepreneur',
        label: 'Entrepreneur',
        description: 'Building businesses, marketing, and leadership.',
      ),
      UserIdentity(
        id: 'student',
        label: 'Student',
        description: 'Learning, studying techniques, and personal growth.',
      ),
      UserIdentity(
        id: 'athlete',
        label: 'Athlete',
        description: 'Physical training, sports science, and mental toughness.',
      ),
      UserIdentity(
        id: 'writer',
        label: 'Writer',
        description: 'Creative writing, storytelling, and publishing.',
      ),
      UserIdentity(
        id: 'designer',
        label: 'Designer',
        description: 'Visual design, UX/UI, and creative inspiration.',
      ),
    ];
  }

  @override
  Future<void> saveActiveIdentityId(String identityId) async {
    await _prefs.setString(_keyIdentityId, identityId);
  }
}
