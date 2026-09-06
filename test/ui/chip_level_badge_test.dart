import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/theme/skin.dart';
import 'package:nested_game/ui/widgets/chip_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await markAllTutorialsCompleted();
  await markAgeGateAnswered();
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Places [level] on [cell] for whoever is to move, through the real staging
/// flow — there is no other way to mutate the board (CLAUDE.md).
Future<void> play(WidgetTester tester, int level, int cell) async {
  await tapKey(tester, 'inventory-$level');
  await tapKey(tester, 'cell-$cell');
  await tapKey(tester, 'confirm');
}

/// The level numerals drawn on the board — the badge inside each cell,
/// excluding the inventory tiles, which carry their own.
Iterable<String> boardLevels(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const Key('cell-4')),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '');

void main() {
  testWidgets('a placed chip shows its level', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'mode-stackStatic');
    await tapKey(tester, 'play-local');

    await play(tester, 2, 4);

    expect(boardLevels(tester), contains('2'));
  });

  testWidgets('covering a chip shows the coverer, never the buried level', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'mode-stackStatic');
    await tapKey(tester, 'play-local');

    // Player 1 places an L1; player 2 covers it with an L2 on the same cell.
    await play(tester, 1, 4);
    await play(tester, 2, 4);

    final shown = boardLevels(tester).toList();

    // The coverer's level is public — you can see the chip.
    expect(shown, contains('2'));
    // The buried one is not. This is the memory mechanic the stacking modes
    // are built on (CLAUDE.md: never reveal what is buried), and a numeral
    // would leak it far more plainly than colour or band count.
    expect(
      shown,
      isNot(contains('1')),
      reason: 'the buried L1 must not be readable through the badge',
    );
  });

  testWidgets('the level badge is off by default', (tester) async {
    // Nothing gets a numeral unless the call site opts in, so a future chip
    // rendered somewhere new cannot leak a level by accident.
    const view = ChipView(
      color: Colors.black,
      ringColor: Colors.white,
      level: 3,
      isFirstPerson: true,
      appearance: PaintedAppearance(ChipForm.rings),
    );
    expect(view.showLevel, isFalse);
  });
}
