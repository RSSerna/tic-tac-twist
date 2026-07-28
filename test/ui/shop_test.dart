import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/ui/screens/shop_screen.dart';
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

  testWidgets('Shop icon on Home opens the Shop with the test item',
      (tester) async {
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-shop');

    expect(find.byType(ShopScreen), findsOneWidget);
    expect(find.byKey(const Key('shop-item-test_item')), findsOneWidget);
    expect(find.byKey(const Key('shop-buy-test_item')), findsOneWidget);
  });

  testWidgets(
      'buying the placeholder item shows the payments-not-set-up notice, '
      'not a real purchase', (tester) async {
    await pumpNestedApp(tester);
    await tapKey(tester, 'open-shop');

    await tester.tap(find.byKey(const Key('shop-buy-test_item')));
    await tester.pump(); // let the SnackBar appear (don't settle it away)

    // The buy button is a placeholder until payments are wired — it must
    // surface the "not set up" notice rather than silently pretending to buy.
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
