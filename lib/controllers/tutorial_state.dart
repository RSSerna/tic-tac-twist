import 'package:meta/meta.dart';

import '../tutorial/tutorial_script.dart';
import '../tutorial/tutorial_step.dart';

/// Where a [GameSession] is within its [TutorialScript], if it's a
/// tutorial session at all. Not persisted (see [GameSession.tutorial]) —
/// an interrupted tutorial just restarts.
@immutable
class TutorialState {
  const TutorialState({required this.script, this.stepIndex = 0});

  final TutorialScript script;
  final int stepIndex;

  TutorialStep get currentStep => script.steps[stepIndex];
  bool get isComplete => currentStep is TutorialComplete;

  TutorialState advance() {
    final next = stepIndex + 1;
    return TutorialState(script: script, stepIndex: next < script.steps.length ? next : stepIndex);
  }
}
