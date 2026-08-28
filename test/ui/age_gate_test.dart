import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/age_gate_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/widgets/buttons/pill_action_button.dart';
import 'package:nested_game/ui/screens/age_gate_screen.dart';
import 'package:nested_game/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

ProviderContainer containerOf(WidgetTester tester, {required Type screen}) =>
    ProviderScope.containerOf(
      tester.element(find.byType(screen)),
      listen: false,
    );

/// The year dropdown lists 101 entries lazily — opening it doesn't build
/// entries far from the top, so picking a year further down needs the
/// popup's own scrollable dragged into view first.
///
/// Uses the plain (non-`.last`) finder for the drag loop: a `.last` finder
/// throws instead of returning empty when nothing matches yet, which is
/// exactly the state before the target year has scrolled into range.
Future<void> selectBirthYear(WidgetTester tester, int year) async {
  await tester.tap(find.byKey(const Key('age-gate-year')));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.text('$year'),
    find.byType(Scrollable).last,
    const Offset(0, -200),
  );
  await tester.tap(find.text('$year').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a never-answered device sees the age gate before Home', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();

    expect(find.byType(AgeGateScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets(
    'answering with an adult birth year classifies as non-child and reaches Home',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: NestedApp()));
      await tester.pumpAndSettle();

      await selectBirthYear(tester, DateTime.now().year - 30);
      await tester.tap(find.byKey(const Key('age-gate-continue')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final isChild = await containerOf(
        tester,
        screen: HomeScreen,
      ).read(ageGateControllerProvider.future);
      expect(isChild, isFalse);
    },
  );

  testWidgets(
    'answering with a birth year under 13 years old classifies as a child',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: NestedApp()));
      await tester.pumpAndSettle();

      await selectBirthYear(tester, DateTime.now().year - 8);
      await tester.tap(find.byKey(const Key('age-gate-continue')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      final isChild = await containerOf(
        tester,
        screen: HomeScreen,
      ).read(ageGateControllerProvider.future);
      expect(isChild, isTrue);
    },
  );

  testWidgets(
    'an already-answered device goes straight to Home, never re-prompted',
    (tester) async {
      await markAgeGateAnswered();
      await tester.pumpWidget(const ProviderScope(child: NestedApp()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AgeGateScreen), findsNothing);
    },
  );

  testWidgets('the Continue button stays disabled until a year is chosen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();

    final button = tester.widget<PillActionButton>(
      find.byKey(const Key('age-gate-continue')),
    );
    expect(button.onPressed, isNull);
  });
}
