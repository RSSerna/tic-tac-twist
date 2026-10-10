import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/board_skin_controller.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/main.dart';
import 'package:nested_game/services/board_skin_service.dart';
import 'package:nested_game/theme/board_skin.dart';
import 'package:nested_game/ui/screens/board_skins_screen.dart';
import 'package:nested_game/ui/screens/game_screen.dart';
import 'package:nested_game/ui/widgets/board_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NestedApp()));
  await tester.pumpAndSettle();
}

Future<void> openBoardPicker(WidgetTester tester) async {
  await pumpApp(tester);
  await tapKey(tester, 'open-skins');
  final tile = find.byKey(const Key('category-board'));
  await tester.scrollUntilVisible(tile, 200);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> startStacking(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(Key('mode-$mode')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('play-local')));
  await tester.pumpAndSettle();
}

BoardSkinState boardState(WidgetTester tester, Type screen) =>
    ProviderScope.containerOf(tester.element(find.byType(screen)), listen: false)
        .read(boardSkinControllerProvider)
        .value!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await markAllTutorialsCompleted();
    await markAgeGateAnswered();
  });

  testWidgets('the Board category opens the picker, Classic equipped', (
    tester,
  ) async {
    await openBoardPicker(tester);

    expect(find.byType(BoardSkinsScreen), findsOneWidget);
    for (final skin in BoardSkin.values) {
      expect(find.byKey(Key('board-tile-${skin.id}')), findsOneWidget);
    }
    expect(find.byKey(const Key('board-equipped-status')), findsOneWidget);
    expect(boardState(tester, BoardSkinsScreen).selected, BoardSkin.classic);
  });

  testWidgets('previewing then selecting a free board equips and persists it', (
    tester,
  ) async {
    await openBoardPicker(tester);

    await tapKey(tester, 'board-tile-sandstone');
    // Previewing is not equipping.
    expect(boardState(tester, BoardSkinsScreen).selected, BoardSkin.classic);
    await tapKey(tester, 'board-select');

    expect(boardState(tester, BoardSkinsScreen).selected, BoardSkin.sandstone);
    expect(find.byKey(const Key('board-equipped-status')), findsOneWidget);
    expect(await SharedPreferencesBoardSkinService().selectedId(), 'sandstone');
  });

  testWidgets('Rock is locked until bought: previewable, not equippable', (
    tester,
  ) async {
    await openBoardPicker(tester);

    await tapKey(tester, 'board-tile-rock');
    expect(find.byKey(const Key('board-locked-hint')), findsOneWidget);
    final select = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('board-select')),
        matching: find.byType(InkWell),
      ),
    );
    expect(select.onTap, isNull);
    expect(boardState(tester, BoardSkinsScreen).selected, BoardSkin.classic);
  });

  for (final skin in [BoardSkin.sandstone, BoardSkin.rock]) {
    testWidgets('${skin.id}: a stacking game plays normally on it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'nested_game.board.selected': skin.id,
        'nested_game.board.unlocked': [skin.id],
      });
      // Seeding replaces the whole mock store, so the setUp marks are gone.
      await markAllTutorialsCompleted();
      await markAgeGateAnswered();
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester);
      await startStacking(tester, 'stackStatic');

      // Real, non-zero cells — a zero-size cell still exists in the tree.
      final board = tester.getRect(find.byType(BoardSurface).first);
      for (var cell = 0; cell < 9; cell++) {
        final rect = tester.getRect(find.byKey(Key('cell-$cell')));
        expect(rect.width, greaterThan(30), reason: 'cell $cell width');
        expect(rect.height, greaterThan(30), reason: 'cell $cell height');
        expect(board.inflate(0.5).contains(rect.center), isTrue);
      }

      // Cells honour the skin's inset: the first sits where the layout says.
      final expected = skin.style.layout.cellRects(board.width).first;
      final first = tester.getRect(find.byKey(const Key('cell-0')));
      expect(first.left - board.left, closeTo(expected.left, 0.5));
      expect(first.top - board.top, closeTo(expected.top, 0.5));

      // Staging and committing still go through the cells on top of the art.
      await tapKey(tester, 'inventory-2');
      await tapKey(tester, 'cell-4');
      await tapKey(tester, 'confirm');
      final engine =
          ProviderScope.containerOf(
                tester.element(find.byType(GameScreen)),
                listen: false,
              ).read(gameControllerProvider)!.engine
              as StackingEngine;
      expect(engine.topChipAt(4), const Chip(Player.one, 2));
    });
  }
}
