import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/ads_controller.dart';
import 'controllers/age_gate_controller.dart';
import 'controllers/settings_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/audio_service.dart';
import 'services/crash_reporting_service.dart';
import 'theme/app_theme.dart';
import 'ui/screens/age_gate_screen.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Built before runApp so global error handlers can be wired before
  // anything else runs — see crash_reporting_service.dart for why the
  // active backend is a no-op until one is configured and swapped in.
  final container = ProviderContainer();
  final crashReporting = container.read(crashReportingServiceProvider);
  await crashReporting.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashReporting.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashReporting.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    UncontrolledProviderScope(container: container, child: const NestedApp()),
  );
}

class NestedApp extends ConsumerWidget {
  const NestedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null (follow system) until settings finish loading, or if the user
    // has never overridden the language — both perfectly reasonable
    // defaults, so there's no need to gate the UI on this resolving first.
    final languageCode = ref
        .watch(settingsControllerProvider)
        .value
        ?.languageCode;

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
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      locale: languageCode == null ? null : Locale(languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _AppRoot(),
    );
  }
}

/// The neutral age screen (product doc §1.1) gates everything else,
/// including ad initialisation — shown once, before Home, then never
/// again once answered.
class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ageGate = ref.watch(ageGateControllerProvider);

    // Ads (and their mixed-audience config, product doc §1) only ever
    // initialise once the age gate has an answer — first resolution
    // covers "already answered on a previous launch"; a value transition
    // covers "just answered it".
    ref.listen(ageGateControllerProvider, (previous, next) {
      final wasAnswered = previous?.value != null;
      final isAnswered = next.value != null;
      if (isAnswered && !wasAnswered) {
        ref.read(adsControllerProvider.notifier).initialize();
      }
    });

    if (!ageGate.hasValue) return const Scaffold(body: SizedBox.shrink());
    if (ageGate.value == null) return const AgeGateScreen();
    return const HomeScreen();
  }
}
