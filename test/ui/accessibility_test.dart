import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
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

void main() {
  testWidgets('stacking cells and inventory chips carry screen-reader labels',
      (tester) async {
    // Direct dispose() in a finally, not addTearDown: in this Flutter
    // version addTearDown callbacks run after the framework's own
    // "handle still active" check, so addTearDown(handle.dispose) always
    // fails that check regardless of the test body.
    final handle = tester.ensureSemantics();
    try {
      await pumpApp(tester);
      await startGame(tester, 'stackStatic');

      expect(find.bySemanticsLabel('Square 1, empty'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Level 1 chip, 3 remaining'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Level 4 chip, 1 remaining'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inventory-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cell-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm')));
      await tester.pumpAndSettle();

      // Occupied + buried info reflects only public information (no owner
      // colour/level ever appears for buried chips — that string doesn't
      // exist in the label vocabulary at all).
      expect(find.bySemanticsLabel('Square 5, player 1 chip, level 1'),
          findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('a zoomed Ultimate cell carries a board+square label',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpApp(tester);
      await startGame(tester, 'ultimate');

      // Unzoomed: the whole small board is one labelled, tappable region.
      expect(find.bySemanticsLabel('Board 5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ult-4-0')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Zoomed: individual cells now carry their own board+square label.
      expect(find.bySemanticsLabel('Board 5, square 1'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
}
