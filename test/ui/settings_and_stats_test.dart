import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/stats/stats_service.dart';
import 'package:nested_game/ui/screens/game_screen.dart';
import 'package:nested_game/ui/screens/home_screen.dart';
import 'package:nested_game/ui/screens/settings_screen.dart';
import 'package:nested_game/ui/screens/stats_screen.dart';
import 'package:nested_game/ui/screens/tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// The Settings screen has more sections than fit the default 800x600 test
/// surface — a tall surface avoids scrolling-into-view flakiness entirely.
Future<void> pumpNestedApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const NestedApp()),
  );
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester, {required Type screen}) =>
    ProviderScope.containerOf(
      tester.element(find.byType(screen)),
      listen: false,
    );

/// Forces the app's ProviderScope (and every provider under it, including
/// GameController) to dispose before the test function returns. Needed
/// whenever a test leaves a turn timer scheduled — the real `Timer` it holds
/// only cancels when the container itself is disposed (a global provider
/// outlives whichever screen navigated away from it), and flutter_test flags
/// any Timer still pending at the end of a test.
Future<void> teardownApp(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
  });

  group('home screen entry points', () {
    testWidgets('Stats and Settings icons open their screens', (tester) async {
      await pumpNestedApp(tester);

      await tapKey(tester, 'open-stats');
      expect(find.byType(StatsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tapKey(tester, 'open-settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('stats screen', () {
    testWidgets('shows an empty state with no games played', (tester) async {
      await pumpNestedApp(tester);
      await tapKey(tester, 'open-stats');

      expect(
        find.text('No games played yet'),
        findsNWidgets(GameMode.values.length),
      );
    });

    testWidgets('reflects a recorded local win by seat', (tester) async {
      await pumpNestedApp(tester);

      final container = containerOf(tester, screen: HomeScreen);
      await container
          .read(statsServiceProvider)
          .recordLocalResult(GameMode.stackStatic, winnerPerson: 1);

      await tapKey(tester, 'open-stats');

      expect(find.textContaining('Player 1: 1'), findsOneWidget);
    });
  });

  group('settings screen', () {
    testWidgets('reset stats clears every mode after confirmation', (
      tester,
    ) async {
      await pumpNestedApp(tester);

      final container = containerOf(tester, screen: HomeScreen);
      await container
          .read(statsServiceProvider)
          .recordLocalResult(GameMode.stackStatic, winnerPerson: 1);

      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'reset-stats');
      expect(find.text('Reset all stats?'), findsOneWidget);
      await tapKey(tester, 'confirm-reset-stats');

      final stats = await container
          .read(statsServiceProvider)
          .statsFor(GameMode.stackStatic);
      expect(stats.local.total, 0);
      expect(find.text('Stats reset'), findsOneWidget);
    });

    testWidgets("replay tutorial navigates to that mode's tutorial", (
      tester,
    ) async {
      await pumpNestedApp(tester);

      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'replay-tutorial-ultimate');

      expect(find.byType(TutorialScreen), findsOneWidget);
      expect(find.byKey(const Key('skip-tutorial')), findsOneWidget);
    });

    testWidgets('switching language changes the app locale', (tester) async {
      await pumpNestedApp(tester);

      await tapKey(tester, 'open-settings');
      expect(find.text('Settings'), findsOneWidget);

      await tapKey(tester, 'language-es');

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets(
      'turn timer preset persists and starts a subsequent game with it set',
      (tester) async {
        await pumpNestedApp(tester);

        await tapKey(tester, 'open-settings');
        await tapKey(tester, 'turn-timer-seconds15');
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tapKey(tester, 'mode-stackStatic');
        await tapKey(tester, 'play-local');

        final session = containerOf(
          tester,
          screen: GameScreen,
        ).read(gameControllerProvider);
        expect(session!.turnTimerSeconds, 15);
        expect(find.byKey(const Key('turn-timer-banner')), findsOneWidget);

        // A real 15s Timer is now pending — force it to cancel before the
        // test ends rather than leaving it dangling (see teardownApp).
        await teardownApp(tester);
      },
    );
  });

  group('turn timer countdown display', () {
    testWidgets('live-updates as time passes', (tester) async {
      await pumpNestedApp(
        tester,
        overrides: [
          turnTimerDurationProvider.overrideWithValue(
            (seconds) => const Duration(seconds: 20),
          ),
        ],
      );

      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'turn-timer-seconds15');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tapKey(tester, 'mode-stackStatic');
      await tapKey(tester, 'play-local');

      int secondsShown() {
        final text =
            tester.widget<Text>(find.byKey(const Key('turn-timer-banner'))).data!;
        return int.parse(text.replaceAll('s', ''));
      }

      // Two clocks are in play here, and neither alone is enough: the
      // display reads real DateTime.now(), but its own re-render is driven
      // by a Timer.periodic created inside testWidgets' fake-async zone.
      // tester.runAsync lets real time actually pass (advancing what
      // DateTime.now() reports), but a fake-zone Timer never fires just
      // because real time passed outside a pump — it only fires when the
      // fake clock itself is advanced. So: let real time pass first, then
      // advance the fake clock to make the periodic ticker fire and
      // pick up the new real elapsed time in its rebuild.
      final initial = secondsShown();
      expect(initial, lessThanOrEqualTo(20));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await tester.pump(const Duration(seconds: 1));
      expect(secondsShown(), lessThan(initial));

      await teardownApp(tester);
    });
  });

  group('abandon guard', () {
    testWidgets(
      'vs AI: confirming leave records a loss and exits; cancel keeps playing',
      (tester) async {
        await pumpNestedApp(
          tester,
          overrides: [
            aiRunnerProvider.overrideWithValue(
              ({required mode, required difficulty, required engine}) async =>
                  engine.legalMoves().first,
            ),
          ],
        );
        await tapKey(tester, 'mode-stackStatic');
        await tapKey(tester, 'play-vs-ai');
        await tapKey(tester, 'difficulty-easy');

        final container = containerOf(tester, screen: GameScreen);
        final navigator = Navigator.of(tester.element(find.byType(GameScreen)));

        // First attempt: cancel keeps the game running.
        navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.text('Leave this game?'), findsOneWidget);
        expect(
          find.text('Abandoning a game vs AI counts as a loss.'),
          findsOneWidget,
        );
        await tapKey(tester, 'abandon-cancel');
        expect(container.read(gameControllerProvider), isNotNull);

        // Second attempt: confirm leaves and records the loss.
        navigator.maybePop();
        await tester.pumpAndSettle();
        await tapKey(tester, 'abandon-confirm');
        await tester.pumpAndSettle();

        expect(container.read(gameControllerProvider), isNull);
        expect(find.byType(GameScreen), findsNothing);
        final stats = await container
            .read(statsServiceProvider)
            .statsFor(GameMode.stackStatic);
        expect(stats.vsAi[Difficulty.easy]!.losses, 1);
      },
    );

    testWidgets(
      'local: leaving mid-game shows local copy and has no stats effect',
      (tester) async {
        await pumpNestedApp(tester);
        await tapKey(tester, 'mode-stackStatic');
        await tapKey(tester, 'play-local');

        final container = containerOf(tester, screen: GameScreen);
        final navigator = Navigator.of(tester.element(find.byType(GameScreen)));

        navigator.maybePop();
        await tester.pumpAndSettle();
        expect(
          find.text('Your progress in this game will be lost.'),
          findsOneWidget,
        );
        await tapKey(tester, 'abandon-confirm');
        await tester.pumpAndSettle();

        expect(find.byType(GameScreen), findsNothing);
        final stats = await container
            .read(statsServiceProvider)
            .statsFor(GameMode.stackStatic);
        expect(stats.local.total, 0);
      },
    );

    testWidgets('a finished game pops normally with no confirmation', (
      tester,
    ) async {
      await pumpNestedApp(tester);
      await tapKey(tester, 'mode-stackStatic');
      await tapKey(tester, 'play-local');

      for (final (level, cell) in [(1, 0), (1, 3), (1, 1), (1, 4), (1, 2)]) {
        await tapKey(tester, 'inventory-$level');
        await tapKey(tester, 'cell-$cell');
        await tapKey(tester, 'confirm');
      }
      expect(find.text('Player 1 wins!'), findsOneWidget);

      final navigator = Navigator.of(tester.element(find.byType(GameScreen)));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Leave this game?'), findsNothing);
      expect(find.byType(GameScreen), findsNothing);
    });
  });
}
