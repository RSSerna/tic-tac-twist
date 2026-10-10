import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/board_skin.dart';

abstract interface class BoardSkinService {
  Future<String> selectedId();
  Future<void> setSelectedId(String id);

  /// Boards unlocked by purchase. Free boards are always available and never
  /// stored here (same arrangement as `SkinService`/`CelebrationService`).
  Future<Set<String>> unlockedIds();
  Future<void> unlock(String id);
}

final boardSkinServiceProvider = Provider<BoardSkinService>(
  (ref) => SharedPreferencesBoardSkinService(),
);

class SharedPreferencesBoardSkinService implements BoardSkinService {
  static const _selectedKey = 'nested_game.board.selected';
  static const _unlockedKey = 'nested_game.board.unlocked';

  @override
  Future<String> selectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey) ?? BoardSkin.defaultChoice.id;
  }

  @override
  Future<void> setSelectedId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
  }

  @override
  Future<Set<String>> unlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_unlockedKey) ?? const []).toSet();
  }

  @override
  Future<void> unlock(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = (prefs.getStringList(_unlockedKey) ?? const []).toSet()
      ..add(id);
    await prefs.setStringList(_unlockedKey, unlocked.toList());
  }
}
