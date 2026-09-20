import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/theme/app_assets.dart';

void main() {
  // A path constant is only worth having if it's guaranteed to resolve. This
  // loads every declared image through the real asset bundle, so a renamed or
  // unbundled file fails here instead of silently showing the widget's
  // fallback icon at runtime.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppImages', () {
    test('every declared path is bundled and loadable', () async {
      for (final path in AppImages.all) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
      }
    });

    test('every declared path lives under assets/images/', () {
      for (final path in AppImages.all) {
        expect(path, startsWith('assets/images/'));
      }
    });
  });

  group('AppIcons', () {
    test('every declared path is bundled and loadable', () async {
      for (final path in AppIcons.all) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: '$path is empty');
      }
    });

    test('every declared path lives under assets/svgs/', () {
      for (final path in AppIcons.all) {
        expect(path, startsWith('assets/svgs/'));
        expect(path, endsWith('.svg'));
      }
    });

    test('every bundled SVG is declared', () async {
      // The other direction: a file dropped into assets/svgs/ that nothing
      // names is either dead weight or an icon someone forgot to wire up.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final bundled = manifest
          .listAssets()
          .where((path) => path.startsWith('assets/svgs/'))
          .toSet();
      expect(bundled, isNotEmpty, reason: 'assets/svgs/ is not bundled');
      expect(bundled.difference(AppIcons.all.toSet()), isEmpty);
    });
  });
}
