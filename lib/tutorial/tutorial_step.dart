import 'package:meta/meta.dart';

import '../engines/common/move.dart';
import 'tutorial_prompt.dart';

/// One beat of a [TutorialScript]. Design doc §7: "run the real engine with
/// a scripted opponent and a prompt overlay driven by move count" — every
/// step maps to exactly one ply (or, for [TutorialMessage], no ply at all),
/// so the overlay is always just "which step are we on".
@immutable
sealed class TutorialStep {
  const TutorialStep(this.prompt);

  final TutorialPrompt prompt;
}

/// An explanatory beat with no move attached. Advances when the player taps
/// "Next" — never on a timer, never on a board tap.
class TutorialMessage extends TutorialStep {
  const TutorialMessage(super.prompt);
}

/// The player must play exactly [move] to advance. Any other tap is
/// rejected by the controller, same as an illegal move would be — the
/// prompt explains what to do and why.
class TutorialHumanMove extends TutorialStep {
  const TutorialHumanMove(super.prompt, this.move);

  final Move move;
}

/// The scripted opponent plays [move] automatically after a short delay.
class TutorialOpponentMove extends TutorialStep {
  const TutorialOpponentMove(this.move) : super(TutorialPrompt.opponentTurn);

  final Move move;
}

/// Terminal step: the lesson is over. Reaching it marks the mode's
/// "tutorial completed" flag once the player dismisses it.
class TutorialComplete extends TutorialStep {
  const TutorialComplete(super.prompt);
}
