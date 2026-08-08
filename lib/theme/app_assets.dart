/// Paths to bundled image assets.
///
/// Widgets reference these constants instead of hand-writing string literals:
/// a typo in a literal only surfaces at runtime (as `Image.asset`'s error
/// state), whereas a typo here is a compile error.
///
/// Skin art is deliberately *not* listed here — it lives under
/// `assets/skins/<skin_id>/` and is built at runtime from the skin id and
/// chip level by each skin's `AssetAppearance.resolve` (see
/// `docs/07-SKINS.md` §4). This file is for fixed, hand-referenced images.
abstract final class AppImages {
  static const String _dir = 'assets/images';

  /// Studio mark shown on the age gate.
  static const String shumiLogo = '$_dir/shumi-logo.png';

  /// Every path declared above. Kept in sync by
  /// `test/theme/app_assets_test.dart`, which loads each one and fails if it
  /// isn't actually bundled — so a missing file is caught by CI rather than
  /// by a player seeing a fallback icon.
  static const List<String> all = <String>[shumiLogo];
}
