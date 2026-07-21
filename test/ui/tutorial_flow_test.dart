import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/analytics_service.dart';
import 'package:nested_game/ui/screens/sub_mode_screen.dart';
import 'package:nested_game/ui/screens/tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> pumpApp(WidgetTester tester, {FakeAnalyticsService? analytics}) async {
  // Fresh, empty store: no tutorial is completed yet — exactly the state
  // that should trigger the auto-tutorial on mode select.
  SharedPreferences.setMockInitialValues({});
  await markAgeGateAnswered();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      if (analytics != null) analyticsServiceProvider.overrideWithValue(analytics),
    ],
    child: const NestedApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Lets a scripted opponent auto-move (700ms delay in the controller)
/// resolve.
Future<void> settleOpponentMove(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening an unfinished mode auto-starts its tutorial', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'mode-stackStatic');

    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.byKey(const Key('tutorial-prompt')), findsOneWidget);
    expect(
      find.text(
          'Stack: Static — bigger chips cover smaller ones. Line up three squares with your color on top to win.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Static tutorial: gates the human move to the script, auto-plays the '
      'opponent, and ends in a real win', (tester) async {
    final analytics = FakeAnalyticsService();
    await pumpApp(tester, analytics: analytics);
    await tapKey(tester, 'mode-stackStatic');

    // Message step: advance with Next.
    await tapKey(tester, 'tutorial-next');

    // Human-move step: a wrong tap stages nothing (and, same as real
    // gameplay, clears the selection — so the level must be re-picked).
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-0'); // wrong square — script wants cell 4
    expect(find.byKey(const Key('confirm')), findsNothing);

    // The scripted move (L1 at cell 4) stages and commits normally.
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-4');
    expect(find.byKey(const Key('confirm')), findsOneWidget);
    await tapKey(tester, 'confirm');

    // Opponent auto-plays; the next step is a message (cover explanation).
    await settleOpponentMove(tester);
    await tapKey(tester, 'tutorial-next');

    // Cover move: L2 onto the opponent's chip at cell 1.
    await tapKey(tester, 'inventory-2');
    await tapKey(tester, 'cell-1');
    await tapKey(tester, 'confirm');
    await tapKey(tester, 'tutorial-next'); // covering-is-permanent recap
    await settleOpponentMove(tester); // opponent plays cell 2

    // L4 move.
    await tapKey(tester, 'inventory-4');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'confirm');
    await tapKey(tester, 'tutorial-next'); // whole-game recap
    await settleOpponentMove(tester); // opponent plays cell 3

    // Winning move: L1 at cell 8 completes the 0-4-8 diagonal.
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-8');
    await tapKey(tester, 'confirm');

    // Completion overlay, and the game really was won.
    expect(find.byKey(const Key('tutorial-continue')), findsOneWidget);
    final engine = ProviderScope.containerOf(
      tester.element(find.byType(TutorialScreen)),
      listen: false,
    ).read(gameControllerProvider)!.engine as StackingEngine;
    expect(engine.topChipAt(0), const Chip(Player.one, 4));
    expect(engine.topChipAt(4), const Chip(Player.one, 1));
    expect(engine.topChipAt(8), const Chip(Player.one, 1));
    expect(engine.status.isOver, isTrue);

    await tapKey(tester, 'tutorial-continue');
    expect(find.byType(SubModeScreen), findsOneWidget);
    expect(analytics.events, ['tutorial_completed:stackStatic']);

    // Reopening the mode from scratch now skips straight past the tutorial.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();
    await tapKey(tester, 'mode-stackStatic');
    expect(find.byType(SubModeScreen), findsOneWidget);
    expect(find.byType(TutorialScreen), findsNothing);
  });

  testWidgets('skipping the tutorial still marks it completed', (tester) async {
    final analytics = FakeAnalyticsService();
    await pumpApp(tester, analytics: analytics);
    await tapKey(tester, 'mode-stackMovable');
    expect(find.byType(TutorialScreen), findsOneWidget);

    await tapKey(tester, 'skip-tutorial');
    expect(find.byType(SubModeScreen), findsOneWidget);
    expect(analytics.events, ['tutorial_skipped:stackMovable']);

    // A fresh relaunch-equivalent: reopening goes straight to sub-mode.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();
    await tapKey(tester, 'mode-stackMovable');
    expect(find.byType(SubModeScreen), findsOneWidget);
    expect(find.byType(TutorialScreen), findsNothing);
  });
}
