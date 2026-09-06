import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/skin.dart';

abstract interface class SkinService {
  /// The skin dressing one player's chips. The two marks are chosen — and
  /// sold — separately, so each has its own stored value.
  Future<String> selectedSkinId({required bool firstPerson});
  Future<void> setSelectedSkinId(String id, {required bool firstPerson});

  /// Premium skins unlocked so far. [GameSkin.turnedWood] is always
  /// unlocked and never stored here.
  Future<Set<String>> unlockedSkinIds();
  Future<void> unlockSkin(String id);

  /// Which chip level dresses this mark in Ultimate, or null for the classic
  /// X/O. Null is the default, so an existing install's Ultimate board looks
  /// exactly as it did.
  Future<int?> ultimateMarkLevel({required bool firstPerson});
  Future<void> setUltimateMarkLevel(int? level, {required bool firstPerson});
}

final skinServiceProvider = Provider<SkinService>(
  (ref) => SharedPreferencesSkinService(),
);

class SharedPreferencesSkinService implements SkinService {
  /// Player 1 keeps the original key, so an install from before skins were
  /// split per mark keeps the skin it had.
  static const _firstPersonKey = 'nested_game.skin.selected';
  static const _secondPersonKey = 'nested_game.skin.selected.p2';
  static const _unlockedKey = 'nested_game.skin.unlocked';
  static const _firstUltimateKey = 'nested_game.skin.ultimate_level';
  static const _secondUltimateKey = 'nested_game.skin.ultimate_level.p2';

  @override
  Future<String> selectedSkinId({required bool firstPerson}) async {
    final prefs = await SharedPreferences.getInstance();
    if (firstPerson) {
      return prefs.getString(_firstPersonKey) ?? GameSkin.turnedWood.id;
    }
    // Falls back to player 1's choice rather than the default: before the
    // split, one skin dressed both, and an upgrade shouldn't silently change
    // how half the board looks.
    return prefs.getString(_secondPersonKey) ??
        prefs.getString(_firstPersonKey) ??
        GameSkin.turnedWood.id;
  }

  @override
  Future<void> setSelectedSkinId(String id, {required bool firstPerson}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      firstPerson ? _firstPersonKey : _secondPersonKey,
      id,
    );
  }

  @override
  Future<int?> ultimateMarkLevel({required bool firstPerson}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(
      firstPerson ? _firstUltimateKey : _secondUltimateKey,
    );
    // Anything outside 1..4 means "classic" — including a level retired by a
    // future change to the chip ladder.
    if (stored == null || stored < 1 || stored > 4) return null;
    return stored;
  }

  @override
  Future<void> setUltimateMarkLevel(
    int? level, {
    required bool firstPerson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = firstPerson ? _firstUltimateKey : _secondUltimateKey;
    if (level == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setInt(key, level);
  }

  @override
  Future<Set<String>> unlockedSkinIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_unlockedKey) ?? const []).toSet();
  }

  @override
  Future<void> unlockSkin(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = (prefs.getStringList(_unlockedKey) ?? const []).toSet()
      ..add(id);
    await prefs.setStringList(_unlockedKey, unlocked.toList());
  }
}
