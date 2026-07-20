import 'package:nested_game/engines/common/game_mode.dart';
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
