import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/celebration.dart';

abstract interface class CelebrationService {
  Future<String> selectedId();
  Future<void> setSelectedId(String id);

  /// Celebrations unlocked by purchase. Free ones are always available and
  /// never stored here (same arrangement as `SkinService`/`EmoteService`).
  Future<Set<String>> unlockedIds();
  Future<void> unlock(String id);

  /// Fragments collected so far toward each fragment-gated celebration
  /// (`Celebration.fragmentsRequired`), keyed by [Celebration.id]. Absent = 0.
  Future<Map<String, int>> fragmentCounts();
  Future<void> setFragmentCount(String id, int count);
}

final celebrationServiceProvider = Provider<CelebrationService>(
  (ref) => SharedPreferencesCelebrationService(),
);

class SharedPreferencesCelebrationService implements CelebrationService {
  static const _selectedKey = 'nested_game.celebration.selected';
  static const _unlockedKey = 'nested_game.celebration.unlocked';
  static const _fragmentsKey = 'nested_game.celebration.fragments';

  @override
  Future<String> selectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey) ?? Celebration.defaultChoice.id;
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
