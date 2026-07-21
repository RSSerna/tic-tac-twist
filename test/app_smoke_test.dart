import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/main.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('app boots and renders the localized home screen',
      (tester) async {
    await markAgeGateAnswered();
    await tester.pumpWidget(const ProviderScope(child: NestedApp()));
    await tester.pumpAndSettle();

    expect(find.text('Nested'), findsOneWidget);
    expect(find.text('Three tic-tac-toe variants'), findsOneWidget);
  });
}
