import 'package:meta/meta.dart';

import '../ai/difficulty.dart';

/// Which persons in a [GameSession] are AI-controlled.
///
/// Person identity (1 or 2) is fixed for the life of a session and is
/// orthogonal to [GameSession.starterPerson] — who is AI never changes
/// between rematches, only who moves first does (rules doc §5: the loser
/// starts, so the AI may go first after beating the human).
@immutable
class SessionOpponents {
  const SessionOpponents._(this.personTwoIsAi, this.difficulty);

  final bool personTwoIsAi;
  final Difficulty? difficulty;

  static const human = SessionOpponents._(false, null);

  factory SessionOpponents.vsAi(Difficulty difficulty) =>
      SessionOpponents._(true, difficulty);

  bool isAiPerson(int person) => person == 2 && personTwoIsAi;
}
