import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/controllers/skin_controller.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/skin_service.dart';
import 'package:nested_game/theme/skin.dart';
import 'package:nested_game/ui/screens/chip_skins_screen.dart';
import 'package:nested_game/ui/widgets/chip_view.dart';
import 'package:nested_game/ui/widgets/ultimate_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Plays one move on the Ultimate board: unzoomed tap zooms in, the second
/// stages, confirm commits. warnIfMissed:false for the same reason
/// game_flow_test gives — the advisory bounds check is imprecise inside the
/// zoom transition, the hit test itself is fine.
Future<void> playUltimate(WidgetTester tester, int board, int cell) async {
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.byKey(Key('ult-$board-$cell')), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
  await tapKey(tester, 'confirm');
}

Future<void> startUltimate(WidgetTester tester) async {
  await tapKey(tester, 'mode-ultimate');
  await tapKey(tester, 'play-local');
}

/// The chip marks currently on the board, by the level each was drawn at.
/// Scoped to the board: the turn banner draws an L1 chip of its own, which
/// has nothing to do with what a mark looks like.
Iterable<int> chipMarks(WidgetTester tester) => tester
    .widgetList<ChipView>(
      find.descendant(
        of: find.byType(UltimateBoard),
        matching: find.byType(ChipView),
      ),
    )
    .map((chip) => chip.level);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets('a levelled skin wears its L4 chip by default', (tester) async {
    await pumpApp(tester);
    await startUltimate(tester);
    await playUltimate(tester, 4, 0);

    // Turned Wood is the default skin and its chips vary by level, so the
    // mark is one of them without anything being chosen — the largest.
    expect(chipMarks(tester), [kDefaultUltimateMarkLevel]);
  });

  testWidgets('a glyph skin keeps the painted X/O — it has no chip to wear', (
    tester,
  ) async {
    await SharedPreferencesSkinService().setSelectedSkinId(
      GameSkin.classicMarks.id,
      firstPerson: true,
    );
    await pumpApp(tester);
    await startUltimate(tester);
    await playUltimate(tester, 4, 0);

    expect(chipMarks(tester), isEmpty);
  });

  testWidgets('a picked level dresses that player\'s Ultimate mark', (
    tester,
  ) async {
    await pumpApp(tester);

    // Person 1 only: person 2's mark is a separate choice and must not
    // follow along.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    await container
        .read(skinControllerProvider.notifier)
        .setUltimateMarkLevel(3, forFirstPerson: true);
    await tester.pumpAndSettle();

    await startUltimate(tester);
    await playUltimate(tester, 4, 0);
    expect(chipMarks(tester), [3]);

    // Person 2 never chose, so their mark falls back to the default rather
    // than following person 1's pick.
    await playUltimate(tester, 0, 1);
    expect(chipMarks(tester), unorderedEquals([3, kDefaultUltimateMarkLevel]));
  });

  testWidgets('the choice survives a restart', (tester) async {
    await SharedPreferencesSkinService().setUltimateMarkLevel(
      2,
      firstPerson: true,
    );

    await pumpApp(tester);
    await startUltimate(tester);
    await playUltimate(tester, 4, 0);
    expect(chipMarks(tester), [2]);
  });

  testWidgets('the picker offers the four chips and nothing else', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'open-skins');
    await tapKey(tester, 'category-chips');
    await tapKey(tester, 'ultimate-mark-level');

    // No classic X/O entry: that's what wearing a glyph skin gives you, and
    // offering it here would let a skin be selected yet never show up.
    expect(find.text('Classic X / O'), findsNothing);
    for (var level = 1; level <= 4; level++) {
      expect(find.text('Level $level chip'), findsWidgets);
    }
  });

  testWidgets('the picker is offered for a levelled skin, not a glyph one', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'open-skins');
    await tapKey(tester, 'category-chips');

    // Turned Wood is focused and already worn, and its chips vary by level —
    // so there is a variant to choose.
    final picker = find.byKey(const Key('ultimate-mark-level'));
    expect(picker, findsOneWidget);

    // Classic draws the same glyph at every level, so once it's worn there
    // is nothing left to pick and the picker goes away.
    final select = find.byKey(Key('select-skin-${GameSkin.classicMarks.id}'));
    for (
      var i = 0;
      i < GameSkin.values.length && select.evaluate().isEmpty;
      i++
    ) {
      await tapKey(tester, 'skins-scroll-forward');
    }
    await tapKey(tester, 'select-skin-${GameSkin.classicMarks.id}');
    expect(picker, findsNothing);
  });

  testWidgets('choosing from the picker persists and applies', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'open-skins');
    await tapKey(tester, 'category-chips');

    await tapKey(tester, 'ultimate-mark-level');
    // Two matches once the menu is open: the item in the closed pill and the
    // one in the overlay. Tapping the last hits the overlay.
    await tester.tap(find.text('Level 4 chip').last);
    await tester.pumpAndSettle();

    final state = await ProviderScope.containerOf(
      tester.element(find.byType(ChipSkinsScreen)),
      listen: false,
    ).read(skinControllerProvider.future);
    expect(state.firstPersonUltimateLevel, 4);
    expect(state.secondPersonUltimateLevel, isNull);
    expect(
      await SharedPreferencesSkinService().ultimateMarkLevel(firstPerson: true),
      4,
    );
  });

  testWidgets('a level chosen on one skin carries to the next', (tester) async {
    // Every levelled skin has all four chips, so the choice stays meaningful
    // across a skin change — and a glyph skin in between simply ignores it.
    await SharedPreferencesSkinService().setUltimateMarkLevel(
      2,
      firstPerson: true,
    );
    await SharedPreferencesSkinService().unlockSkin(GameSkin.nestingDolls.id);
    await pumpApp(tester);
    await tapKey(tester, 'open-skins');
    await tapKey(tester, 'category-chips');

    final select = find.byKey(Key('select-skin-${GameSkin.nestingDolls.id}'));
    for (
      var i = 0;
      i < GameSkin.values.length && select.evaluate().isEmpty;
      i++
    ) {
      await tapKey(tester, 'skins-scroll-forward');
    }
    await tapKey(tester, 'select-skin-${GameSkin.nestingDolls.id}');

    final state = await ProviderScope.containerOf(
      tester.element(find.byType(ChipSkinsScreen)),
      listen: false,
    ).read(skinControllerProvider.future);
    expect(state.firstPersonUltimateLevel, 2);
    expect(state.pair.ultimateLevelFor(isFirstPerson: true), 2);
  });

  testWidgets('a claimed board is stamped with the winner\'s own mark', (
    tester,
  ) async {
    await pumpApp(tester);
    await startUltimate(tester);

    // Player 1 has taken the top row of board 0, so that board is theirs and
    // carries a claim stamp. Built as a position rather than played out: the
    // send rule makes reaching one through nine real moves a long detour
    // from what's being tested.
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    ).read(gameControllerProvider.notifier);
    controller.resumeSession(
      GameSession(
        mode: GameMode.ultimate,
        engine: UltimateEngine.fromJson({
          'cells': [
            for (var i = 0; i < 81; i++)
              if (i == 0 || i == 1 || i == 2) 1 else 0,
          ],
          'currentPlayer': 2,
          'targetBoard': null,
        }),
        starterPerson: 1,
      ),
    );
    await tester.pumpAndSettle();

    final stamp = find.byKey(const ValueKey('claim-one'));
    expect(stamp, findsOneWidget);

    // The stamp wears the skin, at the default level — not a bare painted X.
    final stampChip = find.descendant(
      of: stamp,
      matching: find.byType(ChipView),
    );
    expect(stampChip, findsOneWidget);
    expect(
      tester.widget<ChipView>(stampChip).level,
      kDefaultUltimateMarkLevel,
    );
    expect(
      tester.getSize(stampChip).width,
      greaterThan(10),
      reason: 'the stamp must fill the small board, not collapse',
    );
  });

  testWidgets('a drawn board keeps the neutral disc — it belongs to nobody', (
    tester,
  ) async {
    await pumpApp(tester);
    await startUltimate(tester);

    // Board 0 filled with no line: X X O / O O X / X O X.
    const drawn = [1, 1, 2, 2, 2, 1, 1, 2, 1];
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    ).read(gameControllerProvider.notifier);
    controller.resumeSession(
      GameSession(
        mode: GameMode.ultimate,
        engine: UltimateEngine.fromJson({
          'cells': [for (var i = 0; i < 81; i++) i < 9 ? drawn[i] : 0],
          'currentPlayer': 1,
          'targetBoard': null,
        }),
        starterPerson: 1,
      ),
    );
    await tester.pumpAndSettle();

    final stamp = find.byKey(const ValueKey('drawn'));
    expect(stamp, findsOneWidget);
    expect(
      find.descendant(of: stamp, matching: find.byType(ChipView)),
      findsNothing,
    );
  });
}
