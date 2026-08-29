import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/emote_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/emote_service.dart';
import 'package:nested_game/theme/emote.dart';
import 'package:nested_game/ui/screens/emote_skins_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openEmotes(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
  await tapKey(tester, 'open-skins');
  final chips = find.byKey(const Key('category-emote'));
  await tester.ensureVisible(chips);
  await tester.pumpAndSettle();
  await tester.tap(chips);
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(EmoteSkinsScreen)),
  listen: false,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets('the Emote category opens the loadout screen', (tester) async {
    await openEmotes(tester);

    expect(find.byType(EmoteSkinsScreen), findsOneWidget);
    // Four slots, all empty on a fresh install.
    for (var slot = 0; slot < Emote.loadoutSize; slot++) {
      expect(find.byKey(Key('emote-slot-$slot')), findsOneWidget);
    }
    expect(find.byKey(Key('emote-${Emote.thumbsUp.id}')), findsOneWidget);
  });

  testWidgets('tapping a catalogue emote equips it, tapping again removes it', (
    tester,
  ) async {
    await openEmotes(tester);

    await tapKey(tester, 'emote-${Emote.thumbsUp.id}');
    expect(containerOf(tester).read(emoteControllerProvider).value!.loadout, [
      Emote.thumbsUp,
    ]);

    // The equipped emote stays in the catalogue, and tapping it there is
    // what takes it back out of the loadout.
    await tapKey(tester, 'emote-${Emote.thumbsUp.id}');
    expect(
      containerOf(tester).read(emoteControllerProvider).value!.loadout,
      isEmpty,
    );
  });

  testWidgets('tapping a filled slot empties that slot', (tester) async {
    await openEmotes(tester);

    await tapKey(tester, 'emote-${Emote.thumbsUp.id}');
    await tapKey(tester, 'emote-${Emote.clap.id}');
    await tapKey(tester, 'emote-slot-0');

    expect(containerOf(tester).read(emoteControllerProvider).value!.loadout, [
      Emote.clap,
    ]);
  });

  testWidgets('the loadout stops at four and survives a relaunch', (
    tester,
  ) async {
    await openEmotes(tester);

    final free = Emote.values.where((e) => e.free).toList();
    expect(
      free.length,
      greaterThanOrEqualTo(Emote.loadoutSize),
      reason: 'need enough free emotes to fill the loadout',
    );
    for (final emote in free) {
      await tapKey(tester, 'emote-${emote.id}');
    }

    final loadout = containerOf(tester).read(emoteControllerProvider).value!;
    expect(loadout.loadout.length, Emote.loadoutSize);
    expect(loadout.isFull, isTrue);

    // Persisted, so the next launch comes back with the same four.
    final saved = await SharedPreferencesEmoteService().loadoutIds();
    expect(saved, [for (final e in loadout.loadout) e.id]);
  });

  testWidgets('a locked emote cannot be equipped', (tester) async {
    await openEmotes(tester);

    final locked = Emote.values.firstWhere((e) => !e.free);
    final tile = find.byKey(Key('emote-${locked.id}'));
    // Two scrollables on this screen (the loadout row and the catalogue) —
    // name the catalogue explicitly rather than letting the finder guess.
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(emoteControllerProvider).value!.loadout,
      isEmpty,
    );
  });

  test(
    'a saved loadout naming a retired emote drops it rather than throwing',
    () async {
      SharedPreferences.setMockInitialValues({
        'nested_game.emotes.loadout': ['thumbs_up', 'no_such_emote'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(emoteControllerProvider.future);
      expect(state.loadout, [Emote.thumbsUp]);
    },
  );
}
