import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engines/common/game_mode.dart';

/// Tracks which modes' tutorials have been completed (or explicitly
/// skipped — both count, design doc §7) so each is offered automatically
/// only the first time its mode is opened.
abstract interface class TutorialProgressService {
  Future<bool> isCompleted(GameMode mode);

  Future<void> markCompleted(GameMode mode);
}

final tutorialProgressServiceProvider = Provider<TutorialProgressService>(
  (ref) => SharedPreferencesTutorialProgressService(),
);

class SharedPreferencesTutorialProgressService implements TutorialProgressService {
  static String _key(GameMode mode) => 'nested_game.tutorial_completed.${mode.name}';

  @override
  Future<bool> isCompleted(GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(mode)) ?? false;
  }

  @override
  Future<void> markCompleted(GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(mode), true);
  }
}
