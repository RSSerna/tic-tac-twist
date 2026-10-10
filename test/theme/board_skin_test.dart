import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/theme/board_skin.dart';

void main() {
  test('ids are unique and stable', () {
    final ids = BoardSkin.values.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, ['classic', 'sandstone', 'rock']);
  });

  test('classic is the free default, with no art and no inset', () {
    expect(BoardSkin.defaultChoice, BoardSkin.classic);
    expect(BoardSkin.classic.free, isTrue);
    expect(BoardSkin.classic.style.art, isNull);
    expect(BoardSkin.classic.style.insets, BoardInsets.zero);
    // Today's look: 8px negative space, 4px corners.
    expect(BoardSkin.classic.style.gap, 8);
    expect(BoardSkin.classic.style.cellRadius, 4);
  });

  test('sandstone is a free painted board', () {
    expect(BoardSkin.sandstone.free, isTrue);
    expect(BoardSkin.sandstone.style.art, isA<PaintedBoard>());
  });

  test('rock is purchase-only and asset-backed', () {
    expect(BoardSkin.rock.free, isFalse);
    expect(BoardSkin.rock.purchaseOnly, isTrue);
    final art = BoardSkin.rock.style.art as AssetBoard;
    expect(art.path, 'assets/boards/rock_board.png');
  });

  group('BoardLayout', () {
    test('classic cells tile the board exactly, as squares', () {
      final layout = BoardSkin.classic.style.layout;
      final rects = layout.cellRects(300);
      expect(rects, hasLength(9));
      expect(layout.cellAspect(300), 1);
      expect(rects.first.left, 0);
      expect(rects.last.right, closeTo(300, 1e-9));
      expect(rects.last.bottom, closeTo(300, 1e-9));
    });

    for (final skin in BoardSkin.values) {
      test('${skin.id}: all nine cells sit inside the board with real size', () {
        final rects = skin.style.layout.cellRects(300);
        for (final r in rects) {
          expect(r.width, greaterThan(20));
          expect(r.height, greaterThan(20));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(300));
          expect(r.bottom, lessThanOrEqualTo(300));
        }
      });
    }

    test('insets shift the grid and its first cell with it', () {
      const insets = BoardInsets(left: 0.1, top: 0.2, right: 0.1, bottom: 0.1);
      final layout = BoardLayout(insets: insets, gap: 0);
      expect(layout.gridRect(100).left, closeTo(10, 1e-9));
      expect(layout.cellRects(100).first.top, closeTo(20, 1e-9));
    });
  });
}
