# Nested

Three tic-tac-toe variants in one offline Flutter app: **Stack-Static**, **Stack-Movable**, and **Ultimate**.

- App name: **Nested** · Developer: Ricardo Saldarriaga Serna
- Bundle ID / package: `dev.rsaldarris.nested` (Dart package: `nested_game`, named to avoid colliding with the pub.dev `nested` package)
- Minimums: iOS 13 / Android 6.0 (API 23 — floor for the Google Mobile Ads SDK)
- Targets: iOS + Android (web deferred)

## Development

Project rules live in `CLAUDE.md`; game rules, design system, product, and roadmap in `docs/`.

```sh
flutter pub get
flutter gen-l10n   # regenerates lib/l10n/generated (gitignored)
flutter analyze
flutter test
flutter run
```

Localization is `intl`/ARB (`lib/l10n/app_en.arb`, `app_es.arb`). No hardcoded user-facing strings, colours, or text styles — see `lib/theme/tokens.dart`.
