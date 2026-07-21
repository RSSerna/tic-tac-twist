import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/settings_service.dart';
import 'turn_timer_preset.dart';

@immutable
class AppSettings {
  const AppSettings({
    required this.turnTimer,
    required this.languageCode,
    required this.sfxEnabled,
    required this.musicEnabled,
  });

  final TurnTimerPreset turnTimer;

  /// null = follow the system locale.
  final String? languageCode;

  /// Independent toggles, both on by default (design doc §5).
  final bool sfxEnabled;
  final bool musicEnabled;

  AppSettings copyWith({
    TurnTimerPreset? turnTimer,
    Object? languageCode = _unset,
    bool? sfxEnabled,
    bool? musicEnabled,
  }) =>
      AppSettings(
        turnTimer: turnTimer ?? this.turnTimer,
        languageCode:
            identical(languageCode, _unset) ? this.languageCode : languageCode as String?,
        sfxEnabled: sfxEnabled ?? this.sfxEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
      );

  static const _unset = Object();
}

/// Loads persisted settings once at startup, then mutates them (and
/// persists each change) via [setTurnTimer]/[setLanguageCode]. An
/// [AsyncNotifier] rather than pre-loading in `main()`: keeps every screen
/// that reads settings reactive to changes without restructuring app
/// bootstrap around a required provider override.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final service = ref.read(settingsServiceProvider);
    return AppSettings(
      turnTimer: await service.turnTimerPreset(),
      languageCode: await service.languageCode(),
      sfxEnabled: await service.sfxEnabled(),
      musicEnabled: await service.musicEnabled(),
    );
  }

  Future<void> setTurnTimer(TurnTimerPreset preset) async {
    await ref.read(settingsServiceProvider).setTurnTimerPreset(preset);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(turnTimer: preset));
  }

  Future<void> setLanguageCode(String? code) async {
    await ref.read(settingsServiceProvider).setLanguageCode(code);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(languageCode: code));
  }

  Future<void> setSfxEnabled(bool enabled) async {
    await ref.read(settingsServiceProvider).setSfxEnabled(enabled);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(sfxEnabled: enabled));
  }

  Future<void> setMusicEnabled(bool enabled) async {
    await ref.read(settingsServiceProvider).setMusicEnabled(enabled);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(musicEnabled: enabled));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);
