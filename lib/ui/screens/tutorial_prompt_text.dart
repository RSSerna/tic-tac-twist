import '../../l10n/generated/app_localizations.dart';
import '../../tutorial/tutorial_prompt.dart';

/// Resolves a [TutorialPrompt] to its localized string. Lives in the UI
/// layer (not `lib/tutorial/`) because that's where `AppLocalizations` is
/// available — the tutorial script itself stays pure Dart.
String tutorialPromptText(AppLocalizations l10n, TutorialPrompt prompt) {
  return switch (prompt) {
    TutorialPrompt.opponentTurn => l10n.tutorialOpponentTurn,
    TutorialPrompt.staticIntro => l10n.tutorialStaticIntro,
    TutorialPrompt.staticSpendSmall => l10n.tutorialStaticSpendSmall,
    TutorialPrompt.staticCoverExplain => l10n.tutorialStaticCoverExplain,
    TutorialPrompt.staticCoverMove => l10n.tutorialStaticCoverMove,
    TutorialPrompt.staticCoverRecap => l10n.tutorialStaticCoverRecap,
    TutorialPrompt.staticL4Move => l10n.tutorialStaticL4Move,
    TutorialPrompt.staticL4Recap => l10n.tutorialStaticL4Recap,
    TutorialPrompt.staticWinMove => l10n.tutorialStaticWinMove,
    TutorialPrompt.staticComplete => l10n.tutorialStaticComplete,
    TutorialPrompt.movableIntro => l10n.tutorialMovableIntro,
    TutorialPrompt.movableSpendSmall => l10n.tutorialMovableSpendSmall,
    TutorialPrompt.movableCoverMove => l10n.tutorialMovableCoverMove,
    TutorialPrompt.movableRelocateExplain => l10n.tutorialMovableRelocateExplain,
    TutorialPrompt.movableRelocateMove => l10n.tutorialMovableRelocateMove,
    TutorialPrompt.movableRelocateRecap => l10n.tutorialMovableRelocateRecap,
    TutorialPrompt.movableWinMove => l10n.tutorialMovableWinMove,
    TutorialPrompt.movableComplete => l10n.tutorialMovableComplete,
    TutorialPrompt.ultimateIntro => l10n.tutorialUltimateIntro,
    TutorialPrompt.ultimateFirstMove => l10n.tutorialUltimateFirstMove,
    TutorialPrompt.ultimateSendRule1 => l10n.tutorialUltimateSendRule1,
    TutorialPrompt.ultimateSendRule2 => l10n.tutorialUltimateSendRule2,
    TutorialPrompt.ultimateBuildMove => l10n.tutorialUltimateBuildMove,
    TutorialPrompt.ultimateClaimMove => l10n.tutorialUltimateClaimMove,
    TutorialPrompt.ultimateClaimRecap => l10n.tutorialUltimateClaimRecap,
    TutorialPrompt.ultimateFreeMoveExplain => l10n.tutorialUltimateFreeMoveExplain,
    TutorialPrompt.ultimateFreeMoveMove => l10n.tutorialUltimateFreeMoveMove,
    TutorialPrompt.ultimateComplete => l10n.tutorialUltimateComplete,
  };
}
