import 'package:flutter/material.dart';

import 'tokens.dart';

/// App-wide [ThemeData] built from the design tokens.
///
/// Typography (Bricolage Grotesque / Archivo, design system §2.2) is deferred
/// until the fonts are bundled as assets — the token structure here is what
/// Phase 0 owes.
ThemeData buildAppTheme({GameColors colors = GameColors.baseSkin}) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: colors.ground,
    colorScheme: ColorScheme.light(
      primary: colors.playerA,
      secondary: colors.playerB,
      surface: colors.surface,
      onSurface: colors.ink,
    ),
    extensions: [colors],
  );
}
