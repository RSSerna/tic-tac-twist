/// The two players, symmetric across all engines.
///
/// [one] always moves first in a fresh engine. Match-level seating rules
/// (loser starts the rematch, human starts vs AI) live in the controller,
/// never in an engine.
enum Player {
  one,
  two;

  Player get opponent => this == one ? two : one;

  int toJson() => this == one ? 1 : 2;

  static Player fromJson(Object? json) => switch (json) {
        1 => one,
        2 => two,
        _ => throw FormatException('Invalid player: $json'),
      };
}
