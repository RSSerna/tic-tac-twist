import 'package:meta/meta.dart';

import '../engines/common/game_mode.dart';
import 'stacking_tutorials.dart';
import 'tutorial_step.dart';
import 'ultimate_tutorial.dart';

/// A fixed sequence of [TutorialStep]s for one mode. Fully deterministic —
/// every move is pre-verified legal against the real engine at the point
/// it's played (see the per-mode builders and their test coverage), so the
/// tutorial never needs to branch on what the player does; it only needs
/// to know which step it's on.
@immutable
class TutorialScript {
  const TutorialScript(this.steps);

  final List<TutorialStep> steps;

  factory TutorialScript.forMode(GameMode mode) => switch (mode) {
        GameMode.stackStatic => staticTutorialScript,
        GameMode.stackMovable => movableTutorialScript,
        GameMode.ultimate => ultimateTutorialScript,
      };
}
