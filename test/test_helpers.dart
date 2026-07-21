import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/services/audio_service.dart';
import 'package:nested_game/services/tutorial_progress_service.dart';

/// Marks every mode's tutorial as completed in whatever mock
/// shared_preferences store is currently active. Call after
/// `SharedPreferences.setMockInitialValues({})` in any test that navigates
/// through mode select expecting normal play, not the tutorial trigger —
/// which is everything except the tutorial's own tests.
Future<void> markAllTutorialsCompleted() async {
  final service = SharedPreferencesTutorialProgressService();
  for (final mode in GameMode.values) {
    await service.markCompleted(mode);
  }
}

/// Records every call instead of touching a real platform channel — the
/// default `audioServiceProvider` already no-ops under `flutter test` (see
/// its doc comment), so this is only needed by tests that actually assert on
/// which sounds played or whether music started/stopped.
class FakeAudioService implements AudioService {
  final List<SfxSound> sfxPlayed = [];
  bool musicPlaying = false;

  @override
  Future<void> playSfx(SfxSound sound) async {
    sfxPlayed.add(sound);
  }

  @override
  Future<void> playMusic() async {
    musicPlaying = true;
  }

  @override
  Future<void> stopMusic() async {
    musicPlaying = false;
  }
}
