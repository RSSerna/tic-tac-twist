import '../engines/ultimate/ultimate_move.dart';
import 'tutorial_prompt.dart';
import 'tutorial_script.dart';
import 'tutorial_step.dart';

/// Ultimate tutorial (design doc §7 beats: the send rule — shown explicitly
/// twice — claiming a board, and the free-move rule).
///
/// Every move plays cell index 4 wherever possible for the scripted
/// opponent, which reliably routes play back to board 4 (the send target
/// is always the CELL POSITION just played) — that's what keeps this
/// choreographable without the opponent ever accidentally completing a
/// line of its own. Verified move-by-move against a fresh
/// [UltimateEngine.initial] — see `test/tutorial/tutorial_script_test.dart`.
const ultimateTutorialScript = TutorialScript([
  TutorialMessage(TutorialPrompt.ultimateIntro),
  TutorialHumanMove(TutorialPrompt.ultimateFirstMove, UltimateMove(4, 0)),
  TutorialOpponentMove(UltimateMove(0, 4)),
  TutorialMessage(TutorialPrompt.ultimateSendRule1),
  TutorialHumanMove(TutorialPrompt.ultimateBuildMove, UltimateMove(4, 1)),
  TutorialOpponentMove(UltimateMove(1, 4)),
  TutorialMessage(TutorialPrompt.ultimateSendRule2),
  TutorialHumanMove(TutorialPrompt.ultimateClaimMove, UltimateMove(4, 2)),
  TutorialMessage(TutorialPrompt.ultimateClaimRecap),
  TutorialOpponentMove(UltimateMove(2, 4)),
  TutorialMessage(TutorialPrompt.ultimateFreeMoveExplain),
  TutorialHumanMove(TutorialPrompt.ultimateFreeMoveMove, UltimateMove(0, 0)),
  TutorialComplete(TutorialPrompt.ultimateComplete),
]);
