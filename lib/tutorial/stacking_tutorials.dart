import '../engines/stacking/stacking_move.dart';
import 'tutorial_prompt.dart';
import 'tutorial_script.dart';
import 'tutorial_step.dart';

/// Stack-Static tutorial (rules doc / design doc §7 beats: covering, L4
/// uncoverability, placements are permanent, spend small chips early).
///
/// Every move below is verified legal, in this exact sequence, against a
/// fresh [StackingConfig.staticMode] engine — see
/// `test/tutorial/tutorial_script_test.dart`. The final move wins outright
/// (diagonal 0-4-8), giving the lesson a real payoff.
const staticTutorialScript = TutorialScript([
  TutorialMessage(TutorialPrompt.staticIntro),
  TutorialHumanMove(TutorialPrompt.staticSpendSmall, PlaceMove(1, 4)),
  TutorialOpponentMove(PlaceMove(1, 1)),
  TutorialMessage(TutorialPrompt.staticCoverExplain),
  TutorialHumanMove(TutorialPrompt.staticCoverMove, PlaceMove(2, 1)),
  TutorialMessage(TutorialPrompt.staticCoverRecap),
  TutorialOpponentMove(PlaceMove(1, 2)),
  TutorialHumanMove(TutorialPrompt.staticL4Move, PlaceMove(4, 0)),
  TutorialMessage(TutorialPrompt.staticL4Recap),
  TutorialOpponentMove(PlaceMove(1, 3)),
  TutorialHumanMove(TutorialPrompt.staticWinMove, PlaceMove(1, 8)),
  TutorialComplete(TutorialPrompt.staticComplete),
]);

/// Stack-Movable tutorial: the Static beats above, plus relocating a placed
/// chip and revealing what was underneath it.
///
/// Verified legal, in sequence, against a fresh [StackingConfig.movableMode]
/// engine — see `test/tutorial/tutorial_script_test.dart`.
const movableTutorialScript = TutorialScript([
  TutorialMessage(TutorialPrompt.movableIntro),
  TutorialHumanMove(TutorialPrompt.movableSpendSmall, PlaceMove(1, 4)),
  TutorialOpponentMove(PlaceMove(1, 1)),
  TutorialHumanMove(TutorialPrompt.movableCoverMove, PlaceMove(2, 1)),
  TutorialOpponentMove(PlaceMove(1, 6)),
  TutorialMessage(TutorialPrompt.movableRelocateExplain),
  TutorialHumanMove(TutorialPrompt.movableRelocateMove, RelocateMove(1, 8)),
  TutorialMessage(TutorialPrompt.movableRelocateRecap),
  TutorialOpponentMove(PlaceMove(2, 2)), // L2, not L1 — the opponent's two
  // L1 chips are already spent (cells 1 and 6) in Movable's 6-chip inventory.

  TutorialHumanMove(TutorialPrompt.movableWinMove, PlaceMove(1, 0)),
  TutorialComplete(TutorialPrompt.movableComplete),
]);
