import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/theme/tokens.dart';
import 'package:nested_game/ui/widgets/locked_preview.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [GameColors.baseSkin]),
  home: Scaffold(
    body: Center(child: SizedBox(width: 100, height: 100, child: child)),
  ),
);

void main() {
  testWidgets('locked keeps the art and adds a lock badge', (tester) async {
    await tester.pumpWidget(
      _host(const LockedPreview(locked: true, child: Text('art'))),
    );
    expect(find.text('art'), findsOneWidget);
    expect(find.byKey(const Key('preview-badge-locked')), findsOneWidget);
  });

  testWidgets('unlocked is the bare art; owned adds a check badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const LockedPreview(locked: false, child: Text('art'))),
    );
    expect(find.byType(Positioned), findsNothing);

    await tester.pumpWidget(
      _host(
        const LockedPreview(
          locked: false,
          ownedBadge: true,
          child: Text('art'),
        ),
      ),
    );
    expect(find.byKey(const Key('preview-badge-owned')), findsOneWidget);
  });
}
