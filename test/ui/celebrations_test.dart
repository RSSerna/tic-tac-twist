import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/celebration_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/theme/celebration.dart';
import 'package:nested_game/ui/screens/celebration_skins_screen.dart';
import 'package:nested_game/ui/widgets/buttons/pill_action_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  // The body scrolls on a short screen, so a control can be built but off
  // the fold — and a tap on those coordinates would land on whatever is
  // there instead.
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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

  testWidgets('tapping only previews — the button is what equips', (
    tester,
  ) async {
    await openFlexing(tester);

    final free = Celebration.values.where((c) => c.free).toList();
    final before = stateOf(tester).selectedId;

    await tapKey(tester, 'celebration-${free[1].id}');
    // Look before you commit: the tap moved the preview, not the choice.
    expect(stateOf(tester).selectedId, before);
    expect(find.byKey(const Key('celebration-select')), findsOneWidget);

    await tapKey(tester, 'celebration-select');
    expect(stateOf(tester).selectedId, free[1].id);
    // Once equipped, there's nothing left to commit.
    expect(find.byKey(const Key('celebration-select')), findsNothing);
  });

  testWidgets('a locked celebration previews but never equips', (tester) async {
    await openFlexing(tester);

    final before = stateOf(tester).selectedId;
    final locked = Celebration.values.firstWhere((c) => !c.free);
    await tapKey(tester, 'celebration-${locked.id}');

    expect(stateOf(tester).selectedId, before);
    // Previewing a locked one is the whole point of the lock indicator.
    expect(find.byKey(const Key('celebration-lock-status')), findsOneWidget);

    // The commit button is present but disabled, so the lock is visibly the
    // thing in the way rather than the action having silently vanished.
    final button = tester.widget<PillActionButton>(
      find.byKey(const Key('celebration-select')),
    );
    expect(button.onPressed, isNull);

    await tapKey(tester, 'celebration-select');
    expect(stateOf(tester).selectedId, before);
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

  testWidgets('the equipped celebration is identifiable at all times', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openFlexing(tester);

    // A tick sits on the equipped tile — one, not several.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('celebration-${Celebration.defaultChoice.id}')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    // The tick follows the selection rather than being decorative.
    final free = Celebration.values.where((c) => c.free).toList();
    await tapKey(tester, 'celebration-${free[1].id}');
    await tapKey(tester, 'celebration-select');
    expect(
      find.descendant(
        of: find.byKey(Key('celebration-${free[1].id}')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Previewing a locked one must not make the equipped one unknowable —
    // the status line names it even though the preview shows something else.
    final locked = Celebration.values.firstWhere((c) => !c.free);
    await tapKey(tester, 'celebration-${locked.id}');
    final status = find.byKey(const Key('celebration-equipped-status'));
    expect(status, findsOneWidget);
    expect(
      find.descendant(of: status, matching: find.textContaining('Equipped:')),
      findsOneWidget,
    );

    // Same on a block that doesn't contain the equipped celebration.
    await tapKey(tester, 'celebration-next-block');
    expect(find.byIcon(Icons.check), findsNothing);
    expect(
      find.descendant(of: status, matching: find.textContaining('Equipped:')),
      findsOneWidget,
    );
  });

  testWidgets('the choice survives a relaunch', (tester) async {
    await openFlexing(tester);
    final free = Celebration.values.where((c) => c.free).toList();
    await tapKey(tester, 'celebration-${free[2].id}');
    await tapKey(tester, 'celebration-select');

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
