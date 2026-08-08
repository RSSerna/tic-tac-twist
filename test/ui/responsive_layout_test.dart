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
  await markAgeGateAnswered();
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

/// Taps [finder] after scrolling it fully into view.
///
/// These tests run at deliberately cramped surface sizes, so a target can sit
/// below the fold of a `ListView`. Getting it on screen takes two distinct
/// steps, and skipping either makes the tap silently miss:
///
/// 1. `scrollUntilVisible` gets the widget **built** — a lazy list won't
///    construct an element that far off-screen, so nothing can find it yet.
///    On an already-built target this is a no-op.
/// 2. `ensureVisible` gets it **on screen**. Step 1 stops the moment the
///    element exists, and a `ListView` builds past the viewport edge
///    (`cacheExtent`), so the widget is routinely found while still outside
///    the visible area.
///
/// The settle then lets that scroll finish before the tap — a drag leaves the
/// list moving, and tapping mid-flight hits wherever the target happens to be
/// in that frame. Without all three, whether the tap lands depends on the
/// pixel height of the text above it, so an unrelated change to a font or
/// line height silently breaks these tests.
Future<void> tapAfterScrollingIntoView(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> startGame(WidgetTester tester, String modeName) async {
  await tapAfterScrollingIntoView(tester, find.byKey(Key('mode-$modeName')));
  await tapAfterScrollingIntoView(tester, find.byKey(const Key('play-local')));
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
