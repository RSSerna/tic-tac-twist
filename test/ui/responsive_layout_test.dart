import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/widgets/stacking_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  // Reset the mock store per test — it's process-global, so a game saved
  // by one test would otherwise leak into the next and pop an unexpected
  // resume-game dialog on the home screen. These tests are about layout,
  // not onboarding, so tutorials are pre-completed to skip straight past
  // the tutorial trigger on mode select.
  SharedPreferences.setMockInitialValues({});
  await markAllTutorialsCompleted();
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> startGame(WidgetTester tester, String modeName) async {
  // Small landscape surfaces don't fit every mode card above the fold now
  // that the home screen has an AppBar — scroll the target into the
  // ListView's lazy-build range before tapping it.
  final modeFinder = find.byKey(Key('mode-$modeName'));
  await tester.scrollUntilVisible(modeFinder, 200);
  await tester.tap(modeFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-local')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('portrait phone size renders the stacked layout without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844)); // phone portrait
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester);
    await startGame(tester, 'stackStatic');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(StackingBoard), findsOneWidget);
  });

  testWidgets('landscape phone size renders the side-by-side layout without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390)); // phone landscape
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester);
    await startGame(tester, 'ultimate');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The confirm/cancel bar is squeezed into a narrow side panel here —
    // this is exactly the layout the overflow bug was in.
    expect(find.byType(Wrap), findsWidgets);
  });

  testWidgets('tablet-sized surface caps the board rather than stretching it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600)); // large tablet
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester);
    await startGame(tester, 'stackStatic');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(StackingBoard));
    // Design doc §1: "let boards grow to a sensible maximum with margin" —
    // must not stretch to anywhere near the tablet's own dimensions.
    expect(size.width, lessThanOrEqualTo(640));
    expect(size.height, lessThanOrEqualTo(640));
  });
}
