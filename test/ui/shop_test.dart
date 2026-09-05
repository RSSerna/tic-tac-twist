import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/screens/shop_screen.dart';
import 'package:nested_game/ui/widgets/buttons/pill_action_button.dart';
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets('Shop icon on Home opens the Shop and lists its packs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-shop');

    expect(find.byType(ShopScreen), findsOneWidget);
    for (final id in [
      'fire',
      'apple',
      'elements',
      'sakura',
      'troll',
      'loser',
    ]) {
      expect(find.byKey(Key('shop-item-$id')), findsOneWidget);
    }
  });

  testWidgets('tapping a pack reports that payments are not set up', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-shop');

    await tester.tap(find.byKey(const Key('shop-item-apple')));
    await tester.pump(); // let the SnackBar appear (don't settle it away)

    // Nothing is buyable until real store products exist — a card must say
    // so rather than pretending to sell.
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('the claim meter is empty and Claim is disabled on a fresh day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-shop');

    final meter = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('shop-claim-meter')),
    );
    expect(meter.value, 0);

    final claim = tester.widget<PillActionButton>(
      find.byKey(const Key('shop-claim')),
    );
    expect(claim.onPressed, isNull);
  });
}
