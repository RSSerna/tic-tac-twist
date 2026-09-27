import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/theme/skin.dart';

void main() {
  // Same rationale as app_assets_test.dart: a resolve() that returns the
  // wrong path doesn't fail to compile, it just shows fallback rings at
  // runtime (07-SKINS.md §4 B4) — so load every path it can produce through
  // the real asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameSkin.burgerStack', () {
    test('is purchase-only', () {
      expect(GameSkin.burgerStack.free, isFalse);
      expect(GameSkin.burgerStack.purchaseOnly, isTrue);
    });

    test('resolves a bundled asset for every level, both marks', () async {
      final appearance = GameSkin.burgerStack.appearance as AssetAppearance;
      for (final level in [1, 2, 3, 4]) {
        for (final isFirstPerson in [true, false]) {
          final path = appearance.resolve(
            ChipAssetRequest(isFirstPerson: isFirstPerson, level: level),
          );
          final data = await rootBundle.load(path);
          expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
        }
      }
    });

    test('is in the public catalogue', () {
      expect(GameSkin.values, contains(GameSkin.burgerStack));
    });
  });

  group('GameSkin.fragmentShard', () {
    test('is fragment-gated, and nothing else', () {
      expect(GameSkin.fragmentShard.isFragmentGated, isTrue);
      expect(GameSkin.fragmentShard.fragmentsRequired, 100);
      expect(GameSkin.fragmentShard.free, isFalse);
      expect(GameSkin.fragmentShard.purchaseOnly, isFalse);
    });

    test('uses a painted, not asset, appearance', () {
      expect(GameSkin.fragmentShard.appearance, isA<PaintedAppearance>());
      expect(
        (GameSkin.fragmentShard.appearance as PaintedAppearance).form,
        ChipForm.shards,
      );
    });

    test('is in the public catalogue', () {
      expect(GameSkin.values, contains(GameSkin.fragmentShard));
    });
  });
}
