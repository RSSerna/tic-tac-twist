import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/turn_timer_preset.dart';

/// Persisted app-wide preferences (design doc §10 Settings screen):
/// language and the local turn timer. (SFX/music toggles join this once
/// Phase 7 builds audio.)
abstract interface class SettingsService {
  Future<TurnTimerPreset> turnTimerPreset();
  Future<void> setTurnTimerPreset(TurnTimerPreset preset);

  /// ISO 639-1 code ('en', 'es'), or null to follow the system locale.
  Future<String?> languageCode();
  Future<void> setLanguageCode(String? code);
}

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SharedPreferencesSettingsService());

class SharedPreferencesSettingsService implements SettingsService {
  static const _turnTimerKey = 'nested_game.settings.turn_timer';
  static const _languageKey = 'nested_game.settings.language';

  @override
  Future<TurnTimerPreset> turnTimerPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_turnTimerKey);
    if (name == null) return TurnTimerPreset.off;
    return TurnTimerPreset.values.firstWhere(
      (p) => p.name == name,
      orElse: () => TurnTimerPreset.off,
    );
  }

  @override
  Future<void> setTurnTimerPreset(TurnTimerPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_turnTimerKey, preset.name);
  }

  @override
  Future<String?> languageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  @override
  Future<void> setLanguageCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_languageKey);
    } else {
      await prefs.setString(_languageKey, code);
    }
  }
}
