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
