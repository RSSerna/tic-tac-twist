import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/skin.dart';

abstract interface class SkinService {
  Future<String> selectedSkinId();
  Future<void> setSelectedSkinId(String id);

  /// Premium skins unlocked so far. [GameSkin.turnedWood] is always
  /// unlocked and never stored here.
  Future<Set<String>> unlockedSkinIds();
  Future<void> unlockSkin(String id);
}

final skinServiceProvider =
    Provider<SkinService>((ref) => SharedPreferencesSkinService());

class SharedPreferencesSkinService implements SkinService {
  static const _selectedKey = 'nested_game.skin.selected';
  static const _unlockedKey = 'nested_game.skin.unlocked';

  @override
  Future<String> selectedSkinId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey) ?? GameSkin.turnedWood.id;
  }

  @override
  Future<void> setSelectedSkinId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
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
