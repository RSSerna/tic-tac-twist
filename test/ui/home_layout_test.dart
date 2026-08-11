import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

/// The home screen positions its corner controls in a [Stack] rather than
/// letting a Column lay everything out, so an overflow can't be caught by
/// reading the code. These render it at the extremes — a cramped landscape
/// phone and a tablet — and check nothing throws and every control survives.
void main() {
  const sizes = <String, Size>{
    'phone portrait': Size(390, 844),
    'phone landscape': Size(844, 390),
    'tablet': Size(1200, 1600),
    // Small surfaces are what actually exercises the side inset: they're
    // narrow enough that the corner clusters share a band of height with the
    // mode buttons. Drop the inset and both of these fail.
    'small tall': Size(320, 560),
    'small short': Size(360, 480),
  };

  const controlKeys = [
    'mode-stackStatic',
    'mode-stackMovable',
    'mode-ultimate',
    'open-stats',
    'open-skins',
    'open-shop',
    'open-settings',
    'home-music-toggle',
    'open-challenges',
  ];

  sizes.forEach((name, size) {
    testWidgets('home screen lays out without overflow at $name', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      await markAllTutorialsCompleted();
      await markAgeGateAnswered();
      await tester.pumpWidget(const ProviderScope(child: NestedApp()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final key in controlKeys) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: 'missing $key');
      }
    });
  });

  sizes.forEach((name, size) {
    testWidgets('corner clusters never sit on top of the menu at $name', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      await markAllTutorialsCompleted();
      await markAgeGateAnswered();
      await tester.pumpWidget(const ProviderScope(child: NestedApp()));
      await tester.pumpAndSettle();

      // The clusters run down the sides of a Stack, so nothing stops them
      // covering a mode button — no overflow is reported when they do, and
      // the button underneath silently stops taking taps.
      const clusterKeys = [
        'open-stats',
        'open-skins',
        'open-shop',
        'open-settings',
        'home-music-toggle',
        'open-challenges',
      ];
      const modeKeys = [
        'mode-stackStatic',
        'mode-stackMovable',
        'mode-ultimate',
      ];

      for (final modeKey in modeKeys) {
        final mode = tester.getRect(find.byKey(Key(modeKey)));
        for (final clusterKey in clusterKeys) {
          final control = tester.getRect(find.byKey(Key(clusterKey)));
          expect(
            mode.overlaps(control),
            isFalse,
            reason: '$name: $clusterKey covers $modeKey',
          );
        }
      }
    });
  });

  testWidgets('the challenges button opens the challenge list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-challenges')));
    await tester.pumpAndSettle();

    // Every achievement is listed, and starts locked on a fresh install.
    expect(find.byKey(const Key('challenge-beatImpossibleStatic')), findsOne);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(5));
  });

  testWidgets('the music button reflects and flips the persisted setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();

    // Music defaults to on (design doc §5), so the icon starts unmuted.
    expect(find.byIcon(Icons.music_note), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-music-toggle')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.music_off), findsOneWidget);
  });
}
