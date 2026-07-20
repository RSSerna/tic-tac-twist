import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
      listen: false,
    );

/// Simulates a relaunch: pumping the "same" widget tree again would just
/// rebuild it in place (Flutter reuses the State, so HomeScreen's
/// initState — the resume-check trigger — would NOT fire again). Tearing
/// down to an empty tree first forces a genuinely fresh GameController and
/// HomeScreen, with only the persisted mock store carrying over.
Future<void> relaunch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

void main() {
  // Deliberately NOT reset between relaunches WITHIN a test — the whole
  // point is to simulate the mock shared_preferences store surviving a
  // relaunch, i.e. pumping a brand-new NestedApp widget tree while the
  // "disk" underneath it stays put. Each test still starts from a clean
  // store via its own setUp to stay independent of run order. These tests
  // are about game persistence, not onboarding, so tutorials are
  // pre-completed to skip straight past the tutorial trigger on mode select.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
  });

  testWidgets('an in-progress game is offered back after a simulated relaunch',
      (tester) async {
    // "Session 1": start a game and leave it mid-play — never reaching the
    // result screen, so nothing clears the save.
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();
    await tapKey(tester, 'mode-stackStatic');
    await tapKey(tester, 'play-local');
    await tapKey(tester, 'inventory-2');
    await tapKey(tester, 'cell-4');
    await tapKey(tester, 'confirm');

    await relaunch(tester);

    expect(find.text('Game in progress'), findsOneWidget);
    expect(find.text('You have an unfinished Stack: Static game.'),
        findsOneWidget);

    await tapKey(tester, 'resume-game');

    final engine =
        containerOf(tester).read(gameControllerProvider)!.engine as StackingEngine;
    expect(engine.topChipAt(4), const Chip(Player.one, 2));
    expect(find.text('Player 2 to move'), findsOneWidget);
  });

  testWidgets('abandoning the saved game discards it for good', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();
    await tapKey(tester, 'mode-stackStatic');
    await tapKey(tester, 'play-local');
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'confirm');

    // Relaunch once: abandon instead of resuming.
    await relaunch(tester);
    expect(find.text('Game in progress'), findsOneWidget);
    await tapKey(tester, 'abandon-game');

    // Relaunch again: nothing left to offer.
    await relaunch(tester);
    expect(find.text('Game in progress'), findsNothing);
  });

  testWidgets('a finished game leaves nothing to resume', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();
    await tapKey(tester, 'mode-stackStatic');
    await tapKey(tester, 'play-local');

    // P1 wins along the top row — finishes the game outright.
    for (final (level, cell) in [(1, 0), (1, 3), (1, 1), (1, 4), (1, 2)]) {
      await tapKey(tester, 'inventory-$level');
      await tapKey(tester, 'cell-$cell');
      await tapKey(tester, 'confirm');
    }
    expect(find.text('Player 1 wins!'), findsOneWidget);

    await relaunch(tester);
    expect(find.text('Game in progress'), findsNothing);
  });
}
