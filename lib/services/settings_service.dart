import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/turn_timer_preset.dart';

/// Persisted app-wide preferences (design doc §10 Settings screen):
/// language, the local turn timer, and independent SFX/music toggles.
abstract interface class SettingsService {
  Future<TurnTimerPreset> turnTimerPreset();
  Future<void> setTurnTimerPreset(TurnTimerPreset preset);

  /// ISO 639-1 code ('en', 'es'), or null to follow the system locale.
  Future<String?> languageCode();
  Future<void> setLanguageCode(String? code);

  /// Both default on (design doc §5) and persist independently of each other.
  Future<bool> sfxEnabled();
  Future<void> setSfxEnabled(bool enabled);
  Future<bool> musicEnabled();
  Future<void> setMusicEnabled(bool enabled);
}

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SharedPreferencesSettingsService());

class SharedPreferencesSettingsService implements SettingsService {
  static const _turnTimerKey = 'nested_game.settings.turn_timer';
  static const _languageKey = 'nested_game.settings.language';
  static const _sfxEnabledKey = 'nested_game.settings.sfx_enabled';
  static const _musicEnabledKey = 'nested_game.settings.music_enabled';

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

  @override
  Future<bool> sfxEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sfxEnabledKey) ?? true;
  }

  @override
  Future<void> setSfxEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxEnabledKey, enabled);
  }

  @override
  Future<bool> musicEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_musicEnabledKey) ?? true;
  }

  @override
  Future<void> setMusicEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, enabled);
  }
}
