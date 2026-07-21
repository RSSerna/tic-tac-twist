import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/engines/common/move.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
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

Future<void> startVsAiStackStatic(WidgetTester tester) async {
  await tapKey(tester, 'mode-stackStatic');
  await tapKey(tester, 'play-vs-ai');
  await tapKey(tester, 'difficulty-easy');
}

void main() {
  // Reset the mock store per test — it's process-global, so a game saved
  // by one test would otherwise leak into the next and pop an unexpected
  // resume-game dialog on the home screen. These tests are about vs-AI
  // gameplay, not onboarding, so tutorials are pre-completed to skip
  // straight past the tutorial trigger on mode select.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets(
      'vs AI: human moves, AI thinks in the background, then moves itself',
      (tester) async {
    // A controllable fake stands in for the isolate-based runner — this is
    // exactly why GameController depends on aiRunnerProvider rather than
    // calling AiRunner directly: tests get a fast, deterministic seam
    // instead of a real ~200ms+ search.
    final aiCompleter = Completer<Move>();
    var aiCallCount = 0;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        aiRunnerProvider.overrideWithValue(({
          required mode,
          required difficulty,
          required engine,
        }) {
          aiCallCount++;
          return aiCompleter.future;
        }),
      ],
      child: const NestedApp(),
    ));
    await tester.pumpAndSettle();
    await startVsAiStackStatic(tester);

    // Person 1 is always human vs AI (rules doc §5); they move first.
    expect(find.text('Player 1 to move'), findsOneWidget);

    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-4');
    await tapKey(tester, 'confirm');

    // It's now the AI's turn: the thinking indicator shows, and the board
    // ignores taps rather than staging a move on the AI's behalf.
    await tester.pump();
    expect(find.byKey(const Key('ai-thinking')), findsOneWidget);
    expect(aiCallCount, 1);

    final beforeTap = containerOf(tester).read(gameControllerProvider);
    await tester.tap(find.byKey(const Key('cell-0')), warnIfMissed: false);
    await tester.pump();
    expect(containerOf(tester).read(gameControllerProvider), same(beforeTap),
        reason: 'a tap during the AI\'s turn must not mutate state');

    // Resolve the AI's move.
    aiCompleter.complete(const PlaceMove(1, 0));
    await tester.pumpAndSettle();

    final session = containerOf(tester).read(gameControllerProvider)!;
    expect(session.aiThinking, isFalse);
    expect(find.byKey(const Key('ai-thinking')), findsNothing);
    final engine = session.engine as StackingEngine;
    expect(engine.topChipAt(0), const Chip(Player.two, 1));
    expect(find.text('Player 1 to move'), findsOneWidget);
  });

  testWidgets('a rematch after the human wins lets the AI start', (tester) async {
    // A standing (not one-shot) fake: always plays the first legal move,
    // which for Static is deterministically "smallest chip, lowest empty
    // cell" — deterministic enough to script a human win around it.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        aiRunnerProvider.overrideWithValue(({
          required mode,
          required difficulty,
          required engine,
        }) async =>
            engine.legalMoves().first),
      ],
      child: const NestedApp(),
    ));
    await tester.pumpAndSettle();
    await startVsAiStackStatic(tester);

    // P1 (human) takes 6, 7, 8; the AI's forced replies always land on the
    // lowest remaining empty cell (0, then 1), so it never contests the
    // bottom row before P1 completes it.
    for (final cell in [6, 7, 8]) {
      await tapKey(tester, 'inventory-1');
      await tapKey(tester, 'cell-$cell');
      await tapKey(tester, 'confirm');
    }

    expect(find.text('Player 1 wins!'), findsOneWidget);

    await tapKey(tester, 'rematch');
    // Rubber-band (rules doc §5): the loser (the AI, person 2) starts the
    // rematch — meaning person 2 is now engine Player.one — and since it's
    // AI-controlled, its opening move should have fired and resolved
    // automatically.
    final session = containerOf(tester).read(gameControllerProvider)!;
    expect(session.starterPerson, 2);
    final engine = session.engine as StackingEngine;
    expect(engine.topChipAt(0), const Chip(Player.one, 1));
    expect(find.text('Player 1 to move'), findsOneWidget);
  });
}
