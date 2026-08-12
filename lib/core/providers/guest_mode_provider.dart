import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_prefs_provider.dart';

/// Notifier to manage the Guest Mode state.
class GuestModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const _key = 'sayno_guest_mode';

  GuestModeNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  /// Enables or disables guest mode and persists it to SharedPreferences.
  Future<void> setGuestMode(bool value) async {
    await _prefs.setBool(_key, value);
    state = value;
  }
}

/// Provider for GuestModeNotifier.
final guestModeProvider = StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GuestModeNotifier(prefs);
});
