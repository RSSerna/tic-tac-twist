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
}
