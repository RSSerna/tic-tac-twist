/// Local turn timer presets (design doc §3.6): optional, off by default.
/// On expiry the timed-out player forfeits the game outright — see
/// `GameController._forfeitOnTimeout` — rather than auto-playing a random
/// move, which the design doc explicitly rules out as too punishing.
enum TurnTimerPreset {
  off,
  seconds15,
  seconds30;

  /// Countdown length, or null when the timer is off.
  int? get seconds => switch (this) {
        TurnTimerPreset.off => null,
        TurnTimerPreset.seconds15 => 15,
        TurnTimerPreset.seconds30 => 30,
      };
}
