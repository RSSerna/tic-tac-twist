import '../engines/common/game_engine.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_config.dart';
import '../engines/stacking/stacking_engine.dart';
import '../engines/ultimate/ultimate_engine.dart';

/// The three shipped game modes (v1).
enum GameMode {
  stackStatic,
  stackMovable,
  ultimate;

  bool get isStacking => this != ultimate;

  GameEngine<Move> createEngine() => switch (this) {
        stackStatic => StackingEngine.initial(StackingConfig.staticMode),
        stackMovable => StackingEngine.initial(StackingConfig.movableMode),
        ultimate => UltimateEngine.initial(),
      };
}
