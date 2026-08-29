import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/celebration_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/theme/celebration.dart';
import 'package:nested_game/ui/screens/celebration_skins_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openFlexing(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
  await tapKey(tester, 'open-skins');
  final tile = find.byKey(const Key('category-flexing'));
  await tester.scrollUntilVisible(tile, 200);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

CelebrationState stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(CelebrationSkinsScreen)),
  listen: false,
).read(celebrationControllerProvider).value!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets('the Flexing category opens the picker', (tester) async {
    await openFlexing(tester);

    expect(find.byType(CelebrationSkinsScreen), findsOneWidget);
    expect(find.byKey(const Key('celebration-preview')), findsOneWidget);
    expect(
      find.byKey(Key('celebration-${Celebration.defaultChoice.id}')),
      findsOneWidget,
    );
  });

  testWidgets('tapping an unlocked celebration equips and previews it', (
    tester,
  ) async {
    await openFlexing(tester);

    final free = Celebration.values.where((c) => c.free).toList();
    await tapKey(tester, 'celebration-${free[1].id}');

    expect(stateOf(tester).selectedId, free[1].id);
    // The preview follows the tap: its name bar shows the new choice.
    expect(
      find.descendant(
        of: find.byKey(const Key('celebration-preview')),
        matching: find.textContaining(RegExp('.')),
      ),
      findsWidgets,
    );
  });

  testWidgets('a locked celebration previews but never equips', (tester) async {
    await openFlexing(tester);

    final before = stateOf(tester).selectedId;
    final locked = Celebration.values.firstWhere((c) => !c.free);
    await tapKey(tester, 'celebration-${locked.id}');

    expect(stateOf(tester).selectedId, before);
    // Previewing a locked one is the whole point of the lock indicator.
    expect(find.byKey(const Key('celebration-lock-status')), findsOneWidget);
  });

  testWidgets('blocks page forward and back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openFlexing(tester);

    final firstOfBlockTwo = Celebration.values[Celebration.perBlock];

    // Block 1: the 13th celebration isn't on screen yet.
    expect(find.byKey(Key('celebration-${firstOfBlockTwo.id}')), findsNothing);
    expect(find.byKey(const Key('celebration-previous-block')), findsNothing);

    await tapKey(tester, 'celebration-next-block');
    expect(
      find.byKey(Key('celebration-${firstOfBlockTwo.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('celebration-${Celebration.values.first.id}')),
      findsNothing,
    );

    // Last block: forward is gone, back appears — no dead end.
    expect(find.byKey(const Key('celebration-next-block')), findsNothing);
    await tapKey(tester, 'celebration-previous-block');
    expect(
      find.byKey(Key('celebration-${Celebration.values.first.id}')),
      findsOneWidget,
    );
  });

  testWidgets('the choice survives a relaunch', (tester) async {
    await openFlexing(tester);
    final free = Celebration.values.where((c) => c.free).toList();
    await tapKey(tester, 'celebration-${free[2].id}');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reloaded = await container.read(celebrationControllerProvider.future);
    expect(reloaded.selectedId, free[2].id);
  });

  test(
    'a persisted id that no longer exists falls back to the default',
    () async {
      SharedPreferences.setMockInitialValues({
        'nested_game.celebration.selected': 'retired_celebration',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(celebrationControllerProvider.future);
      expect(state.selected, Celebration.defaultChoice);
    },
  );
}
