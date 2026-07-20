import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/screens/game_screen.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> startGame(WidgetTester tester, String modeName) async {
  await tester.tap(find.byKey(Key('mode-$modeName')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-local')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
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

  testWidgets('ultimate: staging respects the send rule', (tester) async {
    await pumpApp(tester);
    await startGame(tester, 'ultimate');

    await tapKey(tester, 'ult-4-0');
    await tapKey(tester, 'confirm');
    var engine = containerOf(tester).read(gameControllerProvider)!.engine
        as UltimateEngine;
    expect(engine.ownerOf(4, 0), Player.one);
    expect(engine.targetBoard, 0);

    // Tapping outside the target board stages nothing.
    await tapKey(tester, 'ult-1-0');
    expect(find.byKey(const Key('confirm')), findsNothing);

    // Legal cell: stage, then second tap commits.
    await tapKey(tester, 'ult-0-3');
    await tapKey(tester, 'ult-0-3');
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
}
