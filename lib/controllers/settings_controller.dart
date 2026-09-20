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
    this.orientation,
  });

  final TurnTimerPreset turnTimer;

  /// null = follow the system locale.
  final String? languageCode;

  /// Independent toggles, both on by default (design doc §5).
  final bool sfxEnabled;
  final bool musicEnabled;

  /// Which way round the game is held. Null follows the device.
  final ScreenOrientationPreference? orientation;

  AppSettings copyWith({
    TurnTimerPreset? turnTimer,
    Object? languageCode = _unset,
    bool? sfxEnabled,
    bool? musicEnabled,
    Object? orientation = _unset,
  }) =>
      AppSettings(
        turnTimer: turnTimer ?? this.turnTimer,
        languageCode:
            identical(languageCode, _unset) ? this.languageCode : languageCode as String?,
        sfxEnabled: sfxEnabled ?? this.sfxEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        orientation: identical(orientation, _unset)
            ? this.orientation
            : orientation as ScreenOrientationPreference?,
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
      orientation: await service.orientation(),
    );
  }

  /// Flips the game between portrait and landscape.
  ///
  /// Starts from whatever the device is showing (passed in by the caller,
  /// which is the only thing that knows), so the first tap always visibly
  /// does something rather than re-asserting the current orientation.
  Future<void> toggleOrientation({required bool deviceIsPortrait}) async {
    final current = await future;
    final showingPortrait =
        current.orientation == ScreenOrientationPreference.portrait ||
        (current.orientation == null && deviceIsPortrait);
    await setOrientation(
      showingPortrait
          ? ScreenOrientationPreference.landscape
          : ScreenOrientationPreference.portrait,
    );
  }

  Future<void> setOrientation(ScreenOrientationPreference? value) async {
    final current = await future;
    await ref.read(settingsServiceProvider).setOrientation(value);
    state = AsyncData(current.copyWith(orientation: value));
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
