import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  // Reset the mock store per test — it's process-global, so a game saved
  // by one test would otherwise leak into the next and pop an unexpected
  // resume-game dialog on the home screen. These tests are about gameplay,
  // not onboarding, so tutorials are pre-completed to skip straight past
  // the tutorial trigger on mode select.
  SharedPreferences.setMockInitialValues({});
  await markAllTutorialsCompleted();
  await markAgeGateAnswered();
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> startGame(WidgetTester tester, String modeName) async {
  await tester.tap(find.byKey(Key('mode-$modeName')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-local')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key,
    {bool warnIfMissed = true}) async {
  await tester.tap(find.byKey(Key(key)), warnIfMissed: warnIfMissed);
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
      listen: false,
    );

void main() {
  testWidgets('stacking: staging, cancel, and both commit gestures', (
    tester,
  ) async {
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    // Select a chip, stage it, then cancel — nothing commits.
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-4');
    expect(find.byKey(const Key('confirm')), findsOneWidget);
    await tapKey(tester, 'cancel');
    expect(find.byKey(const Key('confirm')), findsNothing);
    var engine =
        containerOf(tester).read(gameControllerProvider)!.engine
            as StackingEngine;
    expect(engine.stackDepthAt(4), 0);

    // Restage and commit via the confirm button.
    await tapKey(tester, 'inventory-2');
    await tapKey(tester, 'cell-4');
    await tapKey(tester, 'confirm');
    engine = containerOf(tester).read(gameControllerProvider)!.engine
        as StackingEngine;
    expect(engine.topChipAt(4), const Chip(Player.one, 2));
    expect(find.text('Player 2 to move'), findsOneWidget);

    // Second-tap-on-target commit for the other player.
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'cell-0');
    engine = containerOf(tester).read(gameControllerProvider)!.engine
        as StackingEngine;
    expect(engine.topChipAt(0), const Chip(Player.two, 1));
    expect(find.text('Player 1 to move'), findsOneWidget);
  });

  testWidgets('movable: relocation stages and commits through the controller',
      (tester) async {
    await pumpApp(tester);
    await startGame(tester, 'stackMovable');

    await tapKey(tester, 'inventory-2');
    await tapKey(tester, 'cell-4');
    await tapKey(tester, 'confirm'); // P1's L2 at 4
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'confirm'); // P2's L1 at 0

    // P1 picks up their visible L2 and covers P2's L1.
    await tapKey(tester, 'cell-4');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'confirm');
    final engine = containerOf(tester).read(gameControllerProvider)!.engine
        as StackingEngine;
    expect(engine.topChipAt(0), const Chip(Player.one, 2));
    expect(engine.stackDepthAt(0), 2);
    expect(engine.stackDepthAt(4), 0);
    expect(find.text('Player 2 to move'), findsOneWidget);
  });

  testWidgets('ultimate: unzoomed tap zooms in; staging respects the send rule',
      (tester) async {
    await pumpApp(tester);
    await startGame(tester, 'ultimate');

    // warnIfMissed:false throughout this test — Flutter's advisory
    // bounds-check on tap() is imprecise for cells inside
    // AnimatedSwitcher's zoom transition; the actual hit-test dispatch is
    // a separate, correct code path (verified by every assertion below
    // actually passing).

    // Unzoomed: a tap on a cell zooms into its board rather than staging.
    await tapKey(tester, 'ult-4-0', warnIfMissed: false);
    expect(find.byKey(const Key('confirm')), findsNothing);
    expect(find.byKey(const Key('zoom-out')), findsOneWidget);

    // Zoomed in: the same cell now stages, and confirm commits it — which
    // also zooms back out to the full board on its own (never stay zoomed
    // into a small board once play has moved on).
    await tapKey(tester, 'ult-4-0', warnIfMissed: false);
    await tapKey(tester, 'confirm');
    expect(find.byKey(const Key('zoom-out')), findsNothing);
    var engine = containerOf(tester).read(gameControllerProvider)!.engine
        as UltimateEngine;
    expect(engine.ownerOf(4, 0), Player.one);
    expect(engine.targetBoard, 0);

    // Zoom into the WRONG board (not the send-rule target) and try to play
    // there: the controller rejects it, nothing stages — and nothing
    // committed, so this does NOT auto-zoom back out.
    await tapKey(tester, 'ult-1-0', warnIfMissed: false); // zooms into board 1
    await tapKey(tester, 'ult-1-0', warnIfMissed: false); // illegal: P2 must play board 0
    expect(find.byKey(const Key('confirm')), findsNothing);
    expect(find.byKey(const Key('zoom-out')), findsOneWidget);

    // Zoom into the correct board: stage, then second tap commits — auto
    // zooms back out again.
    await tapKey(tester, 'zoom-out');
    await tapKey(tester, 'ult-0-3', warnIfMissed: false); // zooms into board 0
    await tapKey(tester, 'ult-0-3', warnIfMissed: false); // stages
    await tapKey(tester, 'ult-0-3', warnIfMissed: false); // second tap commits
    expect(find.byKey(const Key('zoom-out')), findsNothing);
    engine = containerOf(tester).read(gameControllerProvider)!.engine
        as UltimateEngine;
    expect(engine.ownerOf(0, 3), Player.two);
    expect(engine.targetBoard, 3);
  });

  testWidgets('rotation preserves game state', (tester) async {
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'inventory-3');
    await tapKey(tester, 'cell-8');
    await tapKey(tester, 'confirm');

    await tester.binding.setSurfaceSize(const Size(1200, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();

    final engine = containerOf(tester).read(gameControllerProvider)!.engine
        as StackingEngine;
    expect(engine.topChipAt(8), const Chip(Player.one, 3));
    expect(find.text('Player 2 to move'), findsOneWidget);
  });

  testWidgets('result overlay appears and the loser starts the rematch', (
    tester,
  ) async {
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    // P1 wins along the top row.
    for (final (level, cell) in [(1, 0), (1, 3), (1, 1), (1, 4), (1, 2)]) {
      await tapKey(tester, 'inventory-$level');
      await tapKey(tester, 'cell-$cell');
      await tapKey(tester, 'confirm');
    }
    expect(find.text('Player 1 wins!'), findsOneWidget);

    await tapKey(tester, 'rematch');
    final session = containerOf(tester).read(gameControllerProvider)!;
    expect((session.engine as StackingEngine).stackDepthAt(0), 0);
    // Loser (person 2) starts the next game.
    expect(find.text('Player 2 to move'), findsOneWidget);
  });

  testWidgets(
      'reduced motion: a cover that also wins the game renders instantly '
      'with no crash (chip, cover, and winning-line animations all '
      'collapse to zero duration)', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
        () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue());

    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    // P1 already owns cells 1 and 2; P2's L1 sits alone at cell 0. P1's
    // final move covers P2's chip at 0 *and* completes the top row in the
    // same move, exercising the cover animation and the winning-line
    // overlay together.
    final controller = containerOf(tester).read(gameControllerProvider.notifier);
    final engine = StackingEngine.fromJson({
      'config': StackingConfig.staticMode.toJson(),
      'board': [
        [chip(2, 1)], // P2's L1
        [chip(1, 1)], // P1's L1
        [chip(1, 1)], // P1's L1
        <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[],
      ],
      'currentPlayer': 1,
    });
    controller.resumeSession(
      GameSession(mode: GameMode.stackStatic, engine: engine, starterPerson: 1),
    );
    await tester.pumpAndSettle();

    controller.submitMove(const PlaceMove(4, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Player 1 wins!'), findsOneWidget);
  });
}

Map<String, Object?> chip(int owner, int level) => {'owner': owner, 'level': level};
