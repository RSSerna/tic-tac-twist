import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/match_emote_controller.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/emote_service.dart';
import 'package:nested_game/theme/emote.dart';
import 'package:nested_game/ui/screens/game_screen.dart';
import 'package:nested_game/ui/screens/tutorial_screen.dart';
import 'package:nested_game/ui/widgets/emote_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> startGame(WidgetTester tester, String mode) async {
  await tapKey(tester, 'mode-$mode');
  await tapKey(tester, 'play-local');
}

/// Equips the four free emotes, as the Emotes screen would.
Future<List<Emote>> equipFourEmotes() async {
  final free = Emote.values.where((e) => e.free).toList();
  expect(free.length, Emote.loadoutSize, reason: 'test assumes 4 free emotes');
  await SharedPreferencesEmoteService().setLoadoutIds([
    for (final e in free) e.id,
  ]);
  return free;
}

/// The emote inside one seat's bubble, or null if that bubble is empty.
Emote? bubbleEmote(WidgetTester tester, int person) {
  final view = find.descendant(
    of: find.byKey(Key('emote-bubble-$person')),
    matching: find.byType(EmoteView),
  );
  if (view.evaluate().isEmpty) return null;
  return tester.widget<EmoteView>(view).emote;
}

/// Waits out the display and cooldown timers so no timer outlives the test.
Future<void> settleEmoteTimers(WidgetTester tester) async {
  await tester.pump(MatchEmoteController.displayFor);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  for (final mode in ['stackStatic', 'stackMovable', 'ultimate']) {
    testWidgets('$mode: both seat bubbles are reserved and start empty', (
      tester,
    ) async {
      await equipFourEmotes();
      await pumpApp(tester);
      await startGame(tester, mode);

      // The empty bubble is the placeholder: it holds its place in every
      // mode whether or not anything has been sent.
      for (final person in [1, 2]) {
        expect(find.byKey(Key('emote-bubble-$person')), findsOneWidget);
        expect(bubbleEmote(tester, person), isNull);
      }
      expect(find.byKey(const Key('emote-tray-toggle')), findsOneWidget);
    });
  }

  testWidgets('the tray offers all four equipped emotes', (tester) async {
    final equipped = await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    // Closed by default: one button, not a permanent row.
    expect(find.byKey(const Key('emote-tray')), findsNothing);

    await tapKey(tester, 'emote-tray-toggle');
    for (final emote in equipped) {
      expect(find.byKey(Key('send-emote-${emote.id}')), findsOneWidget);
    }
  });

  testWidgets('sending fills the sender\'s bubble, not the opponent\'s', (
    tester,
  ) async {
    final equipped = await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'emote-tray-toggle');
    await tapKey(tester, 'send-emote-${equipped.first.id}');

    // Player 1 is to move, so the tray was theirs.
    expect(bubbleEmote(tester, 1), equipped.first);
    expect(bubbleEmote(tester, 2), isNull);
    // Sending closes the tray.
    expect(find.byKey(const Key('emote-tray')), findsNothing);

    await settleEmoteTimers(tester);
    // It's transient — the bubble empties again on its own.
    expect(bubbleEmote(tester, 1), isNull);
  });

  testWidgets('the tray belongs to whoever is to move', (tester) async {
    final equipped = await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    // Player 1 plays, handing the turn to player 2.
    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'confirm');

    await tapKey(tester, 'emote-tray-toggle');
    await tapKey(tester, 'send-emote-${equipped[1].id}');
    expect(bubbleEmote(tester, 2), equipped[1]);
    expect(bubbleEmote(tester, 1), isNull);

    await settleEmoteTimers(tester);
  });

  testWidgets('a second send is refused until the cooldown passes', (
    tester,
  ) async {
    final equipped = await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'emote-tray-toggle');
    await tapKey(tester, 'send-emote-${equipped.first.id}');

    // Straight back in: the buttons are there but inert.
    await tapKey(tester, 'emote-tray-toggle');
    await tapKey(tester, 'send-emote-${equipped[1].id}');
    expect(bubbleEmote(tester, 1), equipped.first);

    // Once the cooldown lapses, sending works again.
    await tester.pump(MatchEmoteController.cooldown);
    await tester.pumpAndSettle();
    await tapKey(tester, 'send-emote-${equipped[1].id}');
    expect(bubbleEmote(tester, 1), equipped[1]);

    await settleEmoteTimers(tester);
  });

  testWidgets('an empty loadout points at the Emotes screen', (tester) async {
    // Nothing equipped — the default for a fresh install.
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'emote-tray-toggle');
    expect(find.byKey(const Key('emote-tray-empty')), findsOneWidget);
  });

  testWidgets('a new game starts with clean bubbles', (tester) async {
    final equipped = await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'emote-tray-toggle');
    await tapKey(tester, 'send-emote-${equipped.first.id}');
    expect(bubbleEmote(tester, 1), equipped.first);

    // Leave and start again before the bubble would have faded on its own.
    // Back lands on sub-mode select, so the next game starts from there.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapKey(tester, 'abandon-confirm');
    await tapKey(tester, 'play-local');
    expect(bubbleEmote(tester, 1), isNull);
  });

  testWidgets('the tutorial has no tray — nobody to emote at', (tester) async {
    // A fresh store, so no tutorial is marked complete and Stack-Static
    // routes into its lesson instead of a game.
    SharedPreferences.setMockInitialValues({});
    await markAgeGateAnswered();
    await equipFourEmotes();

    await pumpApp(tester);
    // Picking the mode goes straight into the lesson, not sub-mode select.
    await tapKey(tester, 'mode-stackStatic');
    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.byKey(const Key('emote-tray-toggle')), findsNothing);
  });

  testWidgets('the tray stays on screen on a landscape phone', (tester) async {
    // Regression: the landscape side column scrolls, so anything that
    // overflows it lands below the fold — reachable only by scrolling, which
    // nothing tells the player to do. This caught two separate faults: emote
    // bubbles added to that column, and a full-size inventory grid that had
    // already been pushing the staging bar off the bottom before emotes
    // existed at all.
    await equipFourEmotes();
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    final toggle = tester.getRect(find.byKey(const Key('emote-tray-toggle')));
    expect(toggle.bottom, lessThanOrEqualTo(390));

    await tapKey(tester, 'emote-tray-toggle');
    final tray = tester.getRect(find.byKey(const Key('emote-tray')));
    expect(tray.top, greaterThanOrEqualTo(0));
    expect(tray.right, lessThanOrEqualTo(844));
  });

  testWidgets('opening the tray moves nothing', (tester) async {
    // The whole point of floating it: the board, staging bar and bubbles
    // hold their exact positions. A tray that is a layout sibling pushes
    // every one of them.
    await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    Map<String, Rect> snapshot() => {
      'board': tester.getRect(find.byType(BoardArea)),
      'staging': tester.getRect(find.byType(StagingBar)),
      'bubble1': tester.getRect(find.byKey(const Key('emote-bubble-1'))),
      'toggle': tester.getRect(find.byKey(const Key('emote-tray-toggle'))),
    };

    final before = snapshot();
    await tapKey(tester, 'emote-tray-toggle');
    expect(find.byKey(const Key('emote-tray')), findsOneWidget);
    expect(snapshot(), before);
  });

  testWidgets('the tray is aligned to the button, not the screen', (
    tester,
  ) async {
    await equipFourEmotes();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await startGame(tester, 'ultimate');

    final toggle = tester.getRect(find.byKey(const Key('emote-tray-toggle')));
    await tapKey(tester, 'emote-tray-toggle');
    final tray = tester.getRect(find.byKey(const Key('emote-tray')));

    // It hangs off the button it belongs to. The button sits well off-centre
    // in the landscape side column, so centring on the screen instead — the
    // easy thing to do when you don't know the tray's width — is plainly
    // visible and was the first thing to go wrong here.
    expect(tray.center.dx, closeTo(toggle.center.dx, 0.5));
    expect(toggle.center.dx, isNot(closeTo(1280 / 2, 40)));
  });

  testWidgets('a tray near a screen edge slides back on screen', (
    tester,
  ) async {
    // The tray is much wider than the button, and wider again in Spanish, so
    // one centred on a button near the edge would hang off it.
    await equipFourEmotes();
    await tester.binding.setSurfaceSize(const Size(667, 375));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await startGame(tester, 'ultimate');

    await tapKey(tester, 'emote-tray-toggle');
    final tray = tester.getRect(find.byKey(const Key('emote-tray')));
    expect(tray.left, greaterThanOrEqualTo(0));
    expect(tray.right, lessThanOrEqualTo(667));
  });

  testWidgets('the tray opens below the button when there is room for it', (
    tester,
  ) async {
    // Ultimate in landscape: the staging bar sits mid-column, so there's
    // room underneath. Portrait puts the button ~10pt off the bottom edge,
    // where below would open off-screen and it flips above instead.
    await equipFourEmotes();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await startGame(tester, 'ultimate');

    final toggle = tester.getRect(find.byKey(const Key('emote-tray-toggle')));
    await tapKey(tester, 'emote-tray-toggle');
    final tray = tester.getRect(find.byKey(const Key('emote-tray')));
    expect(tray.top, greaterThanOrEqualTo(toggle.bottom));
    expect(tray.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('the tray flips above rather than off the bottom edge', (
    tester,
  ) async {
    await equipFourEmotes();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    final toggle = tester.getRect(find.byKey(const Key('emote-tray-toggle')));
    expect(844 - toggle.bottom, lessThan(88), reason: 'no room below here');

    await tapKey(tester, 'emote-tray-toggle');
    final tray = tester.getRect(find.byKey(const Key('emote-tray')));
    expect(tray.bottom, lessThanOrEqualTo(toggle.top));
    expect(tray.top, greaterThanOrEqualTo(0));
  });

  testWidgets('playing closes an open tray', (tester) async {
    // Two reasons, both real: a turn change would otherwise let the next tap
    // send as a seat the player didn't mean, and the tray works out its
    // position once when it opens — so leaving it up while the staging bar
    // grows a second run would strand it over Confirm.
    await equipFourEmotes();
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'emote-tray-toggle');
    expect(find.byKey(const Key('emote-tray')), findsOneWidget);

    await tapKey(tester, 'inventory-1');
    expect(find.byKey(const Key('emote-tray')), findsNothing);
  });

  testWidgets('an open tray never blocks Confirm', (tester) async {
    // The order that used to break: stage first, *then* open the tray. The
    // bar has wrapped onto a second run by now, and a tray that clears only
    // the button lands squarely on Confirm.
    await equipFourEmotes();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await startGame(tester, 'stackStatic');

    await tapKey(tester, 'inventory-1');
    await tapKey(tester, 'cell-0');
    await tapKey(tester, 'emote-tray-toggle');

    final tray = tester.getRect(find.byKey(const Key('emote-tray')));
    final confirm = tester.getRect(find.byKey(const Key('confirm')));
    expect(tray.overlaps(confirm), isFalse, reason: 'tray sits on Confirm');

    // And it genuinely still commits, rather than merely not overlapping.
    await tapKey(tester, 'confirm');
    expect(find.text('Player 2 to move'), findsOneWidget);
  });
}
