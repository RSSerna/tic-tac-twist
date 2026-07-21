import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/turn_timer_preset.dart';
import 'package:nested_game/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults: timer off, language follows system', () async {
    final service = SharedPreferencesSettingsService();
    expect(await service.turnTimerPreset(), TurnTimerPreset.off);
    expect(await service.languageCode(), isNull);
  });

  test('persists the turn timer preset', () async {
    final service = SharedPreferencesSettingsService();
    await service.setTurnTimerPreset(TurnTimerPreset.seconds15);
    expect(await service.turnTimerPreset(), TurnTimerPreset.seconds15);
    expect(await SharedPreferencesSettingsService().turnTimerPreset(),
        TurnTimerPreset.seconds15);
  });

  test('persists and clears the language override', () async {
    final service = SharedPreferencesSettingsService();
    await service.setLanguageCode('es');
    expect(await service.languageCode(), 'es');
    await service.setLanguageCode(null);
    expect(await service.languageCode(), isNull);
  });
}
