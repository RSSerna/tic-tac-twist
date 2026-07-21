import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/controllers/session_opponents.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

Map<String, Object?> chip(int owner, int level) => {'owner': owner, 'level': level};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeAnalyticsService analytics;
  late ProviderContainer container;
  late GameController controller;

  setUp(() {
    analytics = FakeAnalyticsService();
    container = ProviderContainer(overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
    ]);
    addTearDown(container.dispose);
    controller = container.read(gameControllerProvider.notifier);
  });

  test('startGame fires game_started with mode, opponent type, and difficulty', () {
    controller.startGame(GameMode.stackStatic,
        opponents: SessionOpponents.vsAi(Difficulty.hard));

    expect(analytics.events, ['game_started:stackStatic:ai:hard']);
  });

  test('a local game reports opponent type "human" with no difficulty', () {
    controller.startGame(GameMode.stackStatic);

    expect(analytics.events, ['game_started:stackStatic:human:null']);
  });

  test('a natural win fires game_ended with the winning details', () async {
    controller.startGame(GameMode.stackStatic);
    analytics.events.clear();
    for (final cell in [0, 3, 1, 4, 2]) {
      controller.submitMove(PlaceMove(1, cell));
    }
    await settle();

    expect(analytics.events, ['game_ended:stackStatic:win:line:5:1']);
  });

  test('an exact-tie draw fires game_ended with result "draw"', () async {
    // One ply before test/engines/stacking_static_test.dart's verified
    // "exact tie → draw" fixture (same fixture used in
    // game_controller_stats_test.dart's local-draw test).
    final engine = StackingEngine.fromJson({
      'config': StackingConfig.staticMode.toJson(),
      'board': [
        [chip(2, 1), chip(2, 2), chip(1, 4)],
        [chip(1, 1), chip(2, 2)],
        [chip(2, 1), chip(2, 2)],
        [chip(1, 1), chip(2, 3)],
        <Object?>[],
        [chip(2, 1), chip(1, 3)],
        [chip(1, 2), chip(2, 3)],
        [chip(1, 1), chip(1, 2)],
        [chip(1, 2), chip(2, 4)],
      ],
      'currentPlayer': 1,
    });
    controller.resumeSession(
      GameSession(mode: GameMode.stackStatic, engine: engine, starterPerson: 1),
    );
    analytics.events.clear();
    controller.submitMove(const PlaceMove(3, 2));
    await settle();

    expect(analytics.events, ['game_ended:stackStatic:draw:tiebreak:1:1']);
  });

  test('a timeout forfeit fires game_ended with end_reason "timeout"', () async {
    final container2 = ProviderContainer(overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      turnTimerDurationProvider
          .overrideWithValue((seconds) => const Duration(milliseconds: 20)),
    ]);
    addTearDown(container2.dispose);
    final controller2 = container2.read(gameControllerProvider.notifier);

    final engine = StackingEngine.fromJson({
      'config': StackingConfig.staticMode.toJson(),
      'board': List.generate(9, (_) => <Object?>[]),
      'currentPlayer': 1,
    });
    controller2.resumeSession(GameSession(
      mode: GameMode.stackStatic,
      engine: engine,
      starterPerson: 1,
      turnTimerSeconds: 15,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(
      analytics.events.any((e) => e.startsWith('game_ended:stackStatic:win:timeout:')),
      isTrue,
    );
  });

  test('rematch fires a new game_started event', () {
    controller.startGame(GameMode.stackStatic);
    for (final cell in [0, 3, 1, 4, 2]) {
      controller.submitMove(PlaceMove(1, cell));
    }
    analytics.events.clear();

    controller.rematch();

    expect(analytics.events, ['game_started:stackStatic:human:null']);
  });
}
