import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the one in-progress game across backgrounding, calls, and
/// relaunch (rules doc §5). Stores a single slot — v1 has no concept of
/// multiple concurrent games.
abstract interface class GamePersistenceService {
  /// The saved snapshot, or null if there isn't one (or it was corrupt).
  Future<Map<String, Object?>?> loadSnapshot();

  Future<void> saveSnapshot(Map<String, Object?> snapshot);

  Future<void> clearSnapshot();
}

final gamePersistenceServiceProvider = Provider<GamePersistenceService>(
  (ref) => SharedPreferencesGamePersistenceService(),
);

class SharedPreferencesGamePersistenceService implements GamePersistenceService {
  static const _key = 'nested_game.saved_session.v1';

  @override
  Future<Map<String, Object?>?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on FormatException {
      // Corrupt/unparseable save (e.g. from a future, incompatible version)
      // — don't keep offering a resume that can never succeed.
      await clearSnapshot();
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(Map<String, Object?> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot));
  }

  @override
  Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
