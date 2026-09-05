import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/skin_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/skin_service.dart';
import 'package:nested_game/theme/skin.dart';
import 'package:nested_game/ui/screens/chip_skins_screen.dart';
import 'package:nested_game/ui/screens/skins_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> pumpNestedApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester, {required Type screen}) =>
    ProviderScope.containerOf(
      tester.element(find.byType(screen)),
      listen: false,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets('Skins icon on Home opens the Custom category screen', (
    tester,
  ) async {
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');
    expect(find.byType(SkinsScreen), findsOneWidget);

    // Chips is the only category with content; the rest are locked until
    // they have a system behind them.
    expect(find.byKey(const Key('category-chips')), findsOneWidget);
    for (final locked in ['board', 'emote', 'flexing']) {
      expect(find.byKey(Key('category-$locked')), findsOneWidget);
    }
  });

  testWidgets('the scroll chevron appears only when tiles overflow', (
    tester,
  ) async {
    // Wide enough for all four tiles: no chevron.
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');
    expect(find.byKey(const Key('category-scroll-forward')), findsNothing);

    // Narrow: the chevron shows, and tapping it scrolls the row to the end,
    // at which point there's nothing left to reach and it goes away again.
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-scroll-forward')), findsOneWidget);

    // Tap until it goes away rather than assuming a step count — how many
    // taps reach the end depends on tile and viewport size. The bound just
    // stops a broken chevron from looping forever.
    final chevron = find.byKey(const Key('category-scroll-forward'));
    for (var taps = 0; taps < 6 && chevron.evaluate().isNotEmpty; taps++) {
      await tapKey(tester, 'category-scroll-forward');
    }
    expect(chevron, findsNothing);
  });

  testWidgets('locked categories refuse taps', (tester) async {
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');

    await tester.tap(find.byKey(const Key('category-board')));
    await tester.pumpAndSettle();

    // Still on the category screen — nothing was pushed.
    expect(find.byType(SkinsScreen), findsOneWidget);
    expect(find.byType(ChipSkinsScreen), findsNothing);
  });

  testWidgets(
    'Turned Wood is unlocked and selected by default; Nesting Dolls starts locked',
    (tester) async {
      await pumpNestedApp(tester);
      await tapKey(tester, 'open-skins');
      await tapKey(tester, 'category-chips');

      expect(find.byKey(const Key('skin-card-turned_wood')), findsOneWidget);
      expect(find.byKey(const Key('skin-card-nesting_dolls')), findsOneWidget);

      // Turned Wood starts centred, and it's already the selected skin — so
      // the actions below the carousel say "Selected" rather than offering
      // a Select button.
      expect(find.text('Selected'), findsOneWidget);
      expect(find.byKey(const Key('select-skin-turned_wood')), findsNothing);

      // Nesting Dolls: locked, so its tile shows a lock instead of the art
      // it's selling, and it can't be selected.
      expect(
        find.descendant(
          of: find.byKey(const Key('skin-card-nesting_dolls')),
          matching: find.byIcon(Icons.lock),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('select-skin-nesting_dolls')), findsNothing);
    },
  );

  testWidgets('selecting an unlocked premium skin persists the choice', (
    tester,
  ) async {
    // Pre-unlock the premium skin, as an achievement normally would.
    await SharedPreferencesSkinService().unlockSkin(GameSkin.nestingDolls.id);

    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');
    await tapKey(tester, 'category-chips');

    // Actions belong to the centred skin, so it has to be brought to the
    // centre before it can be selected — tapping its tile does that.
    expect(find.byKey(const Key('select-skin-nesting_dolls')), findsNothing);
    await tapKey(tester, 'skin-card-nesting_dolls');

    expect(find.byKey(const Key('select-skin-nesting_dolls')), findsOneWidget);
    await tapKey(tester, 'select-skin-nesting_dolls');

    final skinState = await containerOf(
      tester,
      screen: ChipSkinsScreen,
    ).read(skinControllerProvider.future);
    // The X/O toggle starts on player 1, so that's the mark this dressed.
    expect(skinState.firstPersonId, GameSkin.nestingDolls.id);
    // Player 2 is a separate purchase and a separate choice — untouched.
    expect(skinState.secondPersonId, GameSkin.turnedWood.id);
    expect(find.text('Selected'), findsOneWidget);
  });
}
