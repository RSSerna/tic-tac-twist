import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/settings_service.dart';
import 'turn_timer_preset.dart';

@immutable
class AppSettings {
  const AppSettings({required this.turnTimer, required this.languageCode});

  final TurnTimerPreset turnTimer;

  /// null = follow the system locale.
  final String? languageCode;

  AppSettings copyWith({TurnTimerPreset? turnTimer, Object? languageCode = _unset}) =>
      AppSettings(
        turnTimer: turnTimer ?? this.turnTimer,
        languageCode:
            identical(languageCode, _unset) ? this.languageCode : languageCode as String?,
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
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);
