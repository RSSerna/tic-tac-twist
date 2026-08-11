import 'package:flutter/material.dart';

import 'app_theme.dart' show kFontFamily;
import 'tokens.dart';

/// The app's text styles, named for *what the text is* rather than for a
/// point on Material's scale.
///
/// Widgets read `context.gameTextStyles.screenTitle` and pass it straight to
/// `Text`. Two things follow from that:
///
/// * **Every style is non-nullable and already coloured**, so call sites stop
///   writing `textTheme.titleLarge?.copyWith(color: colors.ink)` — the colour
///   decision lives here, once, instead of being restated at every `Text`.
/// * **Restyling the app is a single edit in this file.** Change a size or
///   weight here and every screen follows.
///
/// It's a [ThemeExtension] for the same reason [GameColors] and
/// [GameAnimations] are: a skin can substitute the whole set without any
/// widget knowing. Colours come from [GameColors] via [GameTextStyles.from],
/// so a skin that changes `ink` gets correctly-coloured text for free.
@immutable
class GameTextStyles extends ThemeExtension<GameTextStyles> {
  const GameTextStyles({
    required this.display,
    required this.banner,
    required this.screenTitle,
    required this.cardTitle,
    required this.subtitle,
    required this.bodyLarge,
    required this.body,
    required this.bodyMuted,
    required this.label,
    required this.labelMuted,
    required this.caption,
    required this.data,
    required this.dataSmall,
    required this.mainMenuButton,
  });

  /// The app name on the home screen. Used sparingly (design system §2.2).
  final TextStyle display;

  /// Game-over headlines and tutorial page titles.
  final TextStyle banner;

  /// Section and list-row headings.
  final TextStyle screenTitle;

  /// Titles inside cards and list tiles.
  final TextStyle cardTitle;

  /// A line sitting directly under a [display] or [screenTitle] — the home
  /// tagline, a screen's one-line explanation.
  final TextStyle subtitle;

  /// Long-form copy — tutorial paragraphs.
  final TextStyle bodyLarge;

  /// Default running text.
  final TextStyle body;

  /// Running text in a supporting role — blurbs, subtitles, hints.
  final TextStyle bodyMuted;

  /// Buttons and short interactive labels.
  final TextStyle label;

  /// Labels in a supporting role — stat captions, disabled affordances.
  final TextStyle labelMuted;

  /// The smallest utility text. The one place all-caps is acceptable.
  final TextStyle caption;

  /// Stats, timers and counters. Tabular figures so digits keep a fixed
  /// advance width and numbers don't jitter as they tick (design system §2.2).
  final TextStyle data;

  /// [data] for tight spots — inventory counters, badges — where the full
  /// size would crowd the layout.
  final TextStyle dataSmall;

  final TextStyle mainMenuButton;

  /// Builds the scale against a palette. Sizes and weights are fixed; only
  /// the colours vary with the skin.
  factory GameTextStyles.from(GameColors colors) {
    // Bricolage Grotesque is bundled at 400/500/600/700 only — asking for a
    // weight outside that set snaps to the nearest bundled one.
    TextStyle base(
      double size,
      FontWeight weight,
      Color color, {
      double height = 1.3,
      double? letterSpacing,
      List<FontFeature>? features,
    }) => TextStyle(
      fontFamily: kFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );

    return GameTextStyles(
      // Wide tracking on the wordmark, per the home-screen design. Only
      // works because `display` is reserved for a handful of short strings —
      // it would hurt readability on anything longer.
      display: base(
        44,
        FontWeight.w700,
        colors.ink,
        height: 1.1,
        letterSpacing: 6,
      ),
      banner: base(24, FontWeight.w600, colors.ink, height: 1.2),
      screenTitle: base(48, FontWeight.w900, colors.ink, height: 1.2),
      cardTitle: base(16, FontWeight.w600, colors.ink),
      subtitle: base(
        16,
        FontWeight.w400,
        colors.neutral,
        height: 1.35,
        letterSpacing: 2,
      ),
      bodyLarge: base(16, FontWeight.w400, colors.ink, height: 1.45),
      body: base(14, FontWeight.w400, colors.ink, height: 1.4),
      bodyMuted: base(14, FontWeight.w400, colors.neutral, height: 1.4),
      label: base(14, FontWeight.w500, colors.ink),
      labelMuted: base(14, FontWeight.w500, colors.neutral),
      caption: base(12, FontWeight.w400, colors.neutral, height: 1.35),
      data: base(
        14,
        FontWeight.w500,
        colors.ink,
        features: const [FontFeature.tabularFigures()],
      ),
      dataSmall: base(
        12,
        FontWeight.w500,
        colors.ink,
        features: const [FontFeature.tabularFigures()],
      ),
      mainMenuButton: base(32, FontWeight.w400, colors.ink),
    );
  }

  /// Projects this scale onto Material's [TextTheme].
  ///
  /// Widgets we don't build — `DropdownButton`, `FilledButton`, `AppBar`,
  /// dialogs — read Material's slots, not ours. Feeding them from the same
  /// source keeps stock components in step with a restyle here, instead of
  /// leaving two competing type scales in one app.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: banner,
    headlineLarge: banner,
    headlineMedium: banner,
    headlineSmall: banner,
    titleLarge: screenTitle,
    titleMedium: cardTitle,
    titleSmall: subtitle,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: labelMuted,
    labelSmall: caption,
  );

  @override
  GameTextStyles copyWith({
    TextStyle? display,
    TextStyle? banner,
    TextStyle? screenTitle,
    TextStyle? cardTitle,
    TextStyle? subtitle,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? bodyMuted,
    TextStyle? label,
    TextStyle? labelMuted,
    TextStyle? caption,
    TextStyle? data,
    TextStyle? dataSmall,
    TextStyle? mainMenuButton,
  }) {
    return GameTextStyles(
      display: display ?? this.display,
      banner: banner ?? this.banner,
      screenTitle: screenTitle ?? this.screenTitle,
      cardTitle: cardTitle ?? this.cardTitle,
      subtitle: subtitle ?? this.subtitle,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      bodyMuted: bodyMuted ?? this.bodyMuted,
      label: label ?? this.label,
      labelMuted: labelMuted ?? this.labelMuted,
      caption: caption ?? this.caption,
      data: data ?? this.data,
      dataSmall: dataSmall ?? this.dataSmall,
      mainMenuButton: mainMenuButton ?? this.mainMenuButton,
    );
  }

  @override
  GameTextStyles lerp(ThemeExtension<GameTextStyles>? other, double t) {
    if (other is! GameTextStyles) return this;
    return GameTextStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      banner: TextStyle.lerp(banner, other.banner, t)!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyMuted: TextStyle.lerp(bodyMuted, other.bodyMuted, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      labelMuted: TextStyle.lerp(labelMuted, other.labelMuted, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      data: TextStyle.lerp(data, other.data, t)!,
      dataSmall: TextStyle.lerp(dataSmall, other.dataSmall, t)!,
      mainMenuButton: TextStyle.lerp(mainMenuButton, other.mainMenuButton, t)!,
    );
  }
}

extension GameTextStylesContext on BuildContext {
  GameTextStyles get gameTextStyles =>
      Theme.of(this).extension<GameTextStyles>()!;
}
