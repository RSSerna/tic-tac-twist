import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/emote.dart';

abstract interface class EmoteService {
  /// The emotes equipped for a match, in slot order. At most
  /// [Emote.loadoutSize] entries.
  Future<List<String>> loadoutIds();
  Future<void> setLoadoutIds(List<String> ids);

  /// Emotes unlocked by purchase so far. Free emotes are always available
  /// and never stored here (same arrangement as `SkinService`).
  Future<Set<String>> unlockedIds();
  Future<void> unlock(String id);

  /// Fragments collected so far toward each fragment-gated emote
  /// (`Emote.fragmentsRequired`), keyed by [Emote.id]. Absent = 0.
  Future<Map<String, int>> fragmentCounts();
  Future<void> setFragmentCount(String id, int count);
}

final emoteServiceProvider = Provider<EmoteService>(
  (ref) => SharedPreferencesEmoteService(),
);

class SharedPreferencesEmoteService implements EmoteService {
  static const _loadoutKey = 'nested_game.emotes.loadout';
  static const _unlockedKey = 'nested_game.emotes.unlocked';
  static const _fragmentsKey = 'nested_game.emotes.fragments';

  @override
  Future<List<String>> loadoutIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_loadoutKey) ?? const [];
  }

  @override
  Future<void> setLoadoutIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_loadoutKey, ids);
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

  @override
  Future<Map<String, int>> fragmentCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_fragmentsKey);
    if (stored == null) return const {};
    final decoded = jsonDecode(stored) as Map<String, dynamic>;
    return decoded.map((id, count) => MapEntry(id, count as int));
  }

  @override
  Future<void> setFragmentCount(String id, int count) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await fragmentCounts();
    await prefs.setString(_fragmentsKey, jsonEncode({...current, id: count}));
  }
}
