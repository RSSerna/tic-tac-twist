import '../stacking/stacking_config.dart';
import '../stacking/stacking_engine.dart';
import '../ultimate/ultimate_engine.dart';
import 'game_engine.dart';
import 'move.dart';

/// The three shipped game modes (v1).
///
/// Lives beside the engines (not in `controllers/`) because the AI layer
/// needs it too, and AI must not depend on the controller layer.
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
