/// Identifies which localized string a [TutorialStep] shows. Pure data —
/// the tutorial script lives in `lib/tutorial/` (no Flutter dependency);
/// resolving a prompt to actual text happens in the UI layer, which has an
/// `AppLocalizations` to resolve it against.
enum TutorialPrompt {
  /// Shown briefly while a scripted opponent move plays out. Shared across
  /// all three scripts — there's nothing mode-specific to say here.
  opponentTurn,

  staticIntro,
  staticSpendSmall,
  staticCoverExplain,
  staticCoverMove,
  staticCoverRecap,
  staticL4Move,
  staticL4Recap,
  staticWinMove,
  staticComplete,

  movableIntro,
  movableSpendSmall,
  movableCoverMove,
  movableRelocateExplain,
  movableRelocateMove,
  movableRelocateRecap,
  movableWinMove,
  movableComplete,

  ultimateIntro,
  ultimateFirstMove,
  ultimateSendRule1,
  ultimateSendRule2,
  ultimateBuildMove,
  ultimateClaimMove,
  ultimateClaimRecap,
  ultimateFreeMoveExplain,
  ultimateFreeMoveMove,
  ultimateComplete,
}
