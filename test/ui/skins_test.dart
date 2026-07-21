import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/skin_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/skin_service.dart';
import 'package:nested_game/theme/skin.dart';
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

  testWidgets('Skins icon on Home opens the Skins screen', (tester) async {
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');
    expect(find.byType(SkinsScreen), findsOneWidget);
  });

  testWidgets(
      'Turned Wood is unlocked and selected by default; Nesting Dolls starts locked',
      (tester) async {
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');

    expect(find.byKey(const Key('skin-card-turned_wood')), findsOneWidget);
    expect(find.byKey(const Key('skin-card-nesting_dolls')), findsOneWidget);

    // Turned Wood: already selected, no select button.
    expect(
      find.descendant(
        of: find.byKey(const Key('skin-card-turned_wood')),
        matching: find.text('Selected'),
      ),
      findsOneWidget,
    );

    // Nesting Dolls: locked — a lock icon, no select button.
    expect(
      find.descendant(
        of: find.byKey(const Key('skin-card-nesting_dolls')),
        matching: find.byIcon(Icons.lock),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('select-skin-nesting_dolls')), findsNothing);
  });

  testWidgets('selecting an unlocked premium skin persists the choice',
      (tester) async {
    // Pre-unlock the premium skin, as an achievement normally would.
    await SharedPreferencesSkinService().unlockSkin(GameSkin.nestingDolls.id);

    await pumpNestedApp(tester);
    await tapKey(tester, 'open-skins');

    expect(find.byKey(const Key('select-skin-nesting_dolls')), findsOneWidget);
    await tapKey(tester, 'select-skin-nesting_dolls');

    final skinState =
        await containerOf(tester, screen: SkinsScreen).read(skinControllerProvider.future);
    expect(skinState.selectedId, GameSkin.nestingDolls.id);
    expect(
      find.descendant(
        of: find.byKey(const Key('skin-card-nesting_dolls')),
        matching: find.text('Selected'),
      ),
      findsOneWidget,
    );
  });
}
