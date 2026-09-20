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

/// Paths to the bundled SVG icon set.
///
/// Drawn for this project, and the reason `flutter_svg` is a dependency.
/// Every file is authored **white** (`fill: #fff`) on a uniform 101×101
/// viewBox, so nothing here is legible until it's tinted — always draw them
/// through `AppGlyph`, which applies a theme colour rather than letting a
/// call site paint one.
///
/// Not every icon in the app is here. Where there's no drawn glyph for
/// something (Settings, Shop, the AI opponent, the Ultimate zoom-out arrow)
/// the Material icon stays, rather than substituting a near-enough glyph that
/// happens to be in the set.
abstract final class AppIcons {
  static const String _dir = 'assets/svgs';

  /// Dismisses a panel — the X in `PanelHeader`.
  static const String close = '$_dir/close.svg';

  /// Advances a carousel or opens a row that scrolls. Mirrored for the
  /// backwards direction (see `AppGlyph.flipped`).
  static const String chevronRight = '$_dir/rightchevron.svg';

  /// "There's more below" — the hint under a screen's prompt.
  static const String doubleChevronDown = '$_dir/doublechevrondown.svg';

  /// The locked/unavailable idiom (design system §11).
  static const String locked = '$_dir/locked.svg';

  /// Done: a completed challenge, an owned pack, an equipped cosmetic.
  static const String check = '$_dir/checkwithround.svg';

  /// The Shop's badge.
  static const String chest = '$_dir/chest.svg';

  /// Daily goals and achievements.
  static const String objectives = '$_dir/objectives.svg';

  /// Local stats.
  static const String statistics = '$_dir/statistics.svg';

  /// Cosmetics as a whole — the Home shortcut and the category root.
  static const String skins = '$_dir/skins.svg';

  /// The chips category specifically, as against [skins] for all of them.
  static const String chips = '$_dir/XOchips.svg';

  /// Emotes: the category, the picker's badge, and the in-match tray.
  static const String emoji = '$_dir/emoji.svg';

  /// Celebrations ("flexing").
  static const String flex = '$_dir/flex.svg';

  /// Music on. There is no drawn "off" variant, so off is this glyph dimmed
  /// — the same treatment the app already gives anything unavailable.
  static const String music = '$_dir/music.svg';

  /// Switches the game between portrait and landscape.
  static const String rotate = '$_dir/rotate.svg';

  /// A player. **Not wired to anything yet** — profiles/gamertags were
  /// deliberately not built (`05-V2-DEFERRED.md` §4.3). Bundled so it's
  /// ready, and listed here so the asset test keeps it honest.
  static const String user = '$_dir/user.svg';

  /// Every path declared above, checked by `test/theme/app_assets_test.dart`.
  static const List<String> all = <String>[
    close,
    chevronRight,
    doubleChevronDown,
    locked,
    check,
    chest,
    objectives,
    statistics,
    skins,
    chips,
    emoji,
    flex,
    music,
    rotate,
    user,
  ];
}
