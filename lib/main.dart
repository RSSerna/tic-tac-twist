import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/settings_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: NestedApp()));
}

class NestedApp extends ConsumerWidget {
  const NestedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null (follow system) until settings finish loading, or if the user
    // has never overridden the language — both perfectly reasonable
    // defaults, so there's no need to gate the UI on this resolving first.
    final languageCode = ref.watch(settingsControllerProvider).value?.languageCode;

    // Music defaults on (design doc §5) and reacts live to the settings
    // toggle. `previous == null` on the very first resolution is what
    // actually starts it — there's no separate "app launch" hook needed.
    ref.listen(settingsControllerProvider, (previous, next) {
      final wasEnabled = previous?.value?.musicEnabled ?? false;
      final isEnabled = next.value?.musicEnabled ?? false;
      if (isEnabled && !wasEnabled) {
        ref.read(audioServiceProvider).playMusic();
      } else if (!isEnabled && wasEnabled) {
        ref.read(audioServiceProvider).stopMusic();
      }
    });

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      locale: languageCode == null ? null : Locale(languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    );
  }
}
