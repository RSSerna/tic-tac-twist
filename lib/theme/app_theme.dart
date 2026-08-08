import 'package:flutter/material.dart';

import 'tokens.dart';

/// The bundled display/UI typeface (design system §2.2). Declared in
/// pubspec.yaml under this exact family name; the four bundled weights are
/// 400/500/600/700, so avoid asking for weights outside that range — Flutter
/// silently falls back to the nearest bundled one.
const String kFontFamily = 'BricolageGrotesque';

/// App-wide [ThemeData] built from the design tokens.
///
/// Typography is Bricolage Grotesque throughout. Design system §2.2 pairs it
/// with Archivo for UI/body text and tabular figures; Archivo isn't bundled
/// yet, so Bricolage carries both roles for now.
ThemeData buildAppTheme({
  GameColors colors = GameColors.baseSkin,
  GameAnimations animations = GameAnimations.standard,
}) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    scaffoldBackgroundColor: colors.ground,
    colorScheme: ColorScheme.light(
      primary: colors.playerA,
      secondary: colors.playerB,
      surface: colors.surface,
      onSurface: colors.ink,
    ),
    extensions: [colors, animations],
  );
}
