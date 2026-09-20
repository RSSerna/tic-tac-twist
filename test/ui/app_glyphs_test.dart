import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/theme/app_assets.dart';
import 'package:nested_game/theme/app_theme.dart';
import 'package:nested_game/ui/widgets/app_glyph.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

/// Every screen that carries at least one drawn glyph, and the taps that
/// reach it from a fresh Home.
const _routes = {
  'home': <String>[],
  'custom': ['open-skins'],
  'chips': ['open-skins', 'category-chips'],
  'emotes': ['open-skins', 'category-emote'],
  'flexing': ['open-skins', 'category-flexing'],
  'shop': ['open-shop'],
  'challenges': ['open-challenges'],
  'game': ['mode-stackStatic', 'play-local'],
};

Future<void> openRoute(WidgetTester tester, List<String> keys) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
  for (final key in keys) {
    final finder = find.byKey(Key(key));
    expect(finder, findsOneWidget, reason: 'could not reach $key');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  for (final route in _routes.entries) {
    testWidgets('${route.key}: every drawn glyph renders at a sane size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openRoute(tester, route.value);

      final glyphs = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(glyphs, isNotEmpty, reason: 'no drawn glyph on ${route.key}');
      for (final glyph in glyphs) {
        final box = tester.renderObject(find.byWidget(glyph)) as RenderBox;
        // The icons are 101×101 in their own viewBox. An AppGlyph that
        // doesn't resolve a size falls through to those intrinsics and
        // renders four times the icon it replaced, shoving everything below
        // it off the screen — which is exactly what happened first time.
        expect(
          box.size.width,
          inInclusiveRange(8, 120),
          reason: '${route.key}: glyph at ${box.size}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unsized glyph takes the icon size, not the SVG size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Row(children: [AppGlyph(AppIcons.check)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Unbounded (a Row), no explicit size, no IconTheme: it must land on the
    // 24pt icon default rather than the file's own 101.
    final box = tester.renderObject(find.byType(SvgPicture)) as RenderBox;
    expect(box.size.width, 24);
  });

  testWidgets('a glyph is tinted from the theme, never left white', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: AppGlyph(AppIcons.locked, size: 20)),
      ),
    );
    await tester.pumpAndSettle();

    // Every file in the set is authored white, so an untinted one is
    // invisible on the app's light surfaces. The filter is what makes them
    // show up at all — and what carries state (dimmed, player colour).
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.colorFilter, isNotNull);
  });
}
