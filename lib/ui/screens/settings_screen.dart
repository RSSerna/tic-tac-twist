import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/settings_controller.dart';
import '../../controllers/turn_timer_preset.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/purchase_service.dart';
import '../../services/stats/stats_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'tutorial_screen.dart';

String _modeName(AppLocalizations l10n, GameMode mode) => switch (mode) {
      GameMode.stackStatic => l10n.modeStackStatic,
      GameMode.stackMovable => l10n.modeStackMovable,
      GameMode.ultimate => l10n.modeUltimate,
    };

/// Design doc §10: reset stats, replay tutorial, sound toggles, language,
/// local turn timer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final settings = ref.watch(settingsControllerProvider).value;
    final settingsController = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SectionCard(
              title: l10n.settingsResetStats,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('reset-stats'),
                  onPressed: () => _confirmResetStats(context, ref),
                  child: Text(l10n.settingsResetStats),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.settingsReplayTutorialHeading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final mode in GameMode.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: TextButton(
                        key: Key('replay-tutorial-${mode.name}'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => TutorialScreen(mode: mode)),
                        ),
                        child: Text(_modeName(l10n, mode)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.settingsSoundHeading,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('sfx-toggle'),
                    title: Text(l10n.settingsSfxLabel),
                    value: settings?.sfxEnabled ?? true,
                    onChanged: (value) => settingsController.setSfxEnabled(value),
                  ),
                  SwitchListTile(
                    key: const Key('music-toggle'),
                    title: Text(l10n.settingsMusicLabel),
                    value: settings?.musicEnabled ?? true,
                    onChanged: (value) => settingsController.setMusicEnabled(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.settingsLanguageHeading,
              child: RadioGroup<String?>(
                groupValue: settings?.languageCode,
                onChanged: (code) => settingsController.setLanguageCode(code),
                child: Column(
                  children: [
                    RadioListTile<String?>(
                      key: const Key('language-system'),
                      title: Text(l10n.languageSystem),
                      value: null,
                    ),
                    RadioListTile<String?>(
                      key: const Key('language-en'),
                      title: Text(l10n.languageEnglish),
                      value: 'en',
                    ),
                    RadioListTile<String?>(
                      key: const Key('language-es'),
                      title: Text(l10n.languageSpanish),
                      value: 'es',
                    ),
                  ],
                ),
              ),
            ),
            // Web is inherently ad-free and purchase-free (design doc §9) —
            // AdMob and in_app_purchase have no web implementation, so
            // there's nothing to remove and nothing to buy there.
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              const _RemoveAdsSection(),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: l10n.settingsTurnTimerHeading,
              child: RadioGroup<TurnTimerPreset>(
                groupValue: settings?.turnTimer,
                onChanged: (value) {
                  if (value != null) settingsController.setTurnTimer(value);
                },
                child: Column(
                  children: [
                    for (final preset in TurnTimerPreset.values)
                      RadioListTile<TurnTimerPreset>(
                        key: Key('turn-timer-${preset.name}'),
                        title: Text(preset == TurnTimerPreset.off
                            ? l10n.turnTimerOff
                            : l10n.turnTimerSeconds(preset.seconds!)),
                        value: preset,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetStats(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsResetStatsConfirmTitle),
        content: Text(l10n.settingsResetStatsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-reset-stats'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsReset),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(statsServiceProvider).resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsResetStatsDone)),
    );
  }
}

/// Remove-ads IAP (product doc §2.1: "highest-converting purchase... nearly
/// free to implement") plus restore-purchases. Manages its own tiny bit of
/// state (the current entitlement) since it's the one thing on this screen
/// that isn't driven by a Riverpod controller — a real purchase completes
/// asynchronously via the platform's own purchase stream, not synchronously
/// from tapping "Buy".
class _RemoveAdsSection extends ConsumerStatefulWidget {
  const _RemoveAdsSection();

  @override
  ConsumerState<_RemoveAdsSection> createState() => _RemoveAdsSectionState();
}

class _RemoveAdsSectionState extends ConsumerState<_RemoveAdsSection> {
  late Future<bool> _removed;

  @override
  void initState() {
    super.initState();
    _removed = ref.read(purchaseServiceProvider).isRemoved();
  }

  void _refresh() => setState(() {
        _removed = ref.read(purchaseServiceProvider).isRemoved();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _SectionCard(
      title: l10n.removeAdsTitle,
      child: FutureBuilder<bool>(
        future: _removed,
        builder: (context, snapshot) {
          final removed = snapshot.data ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.removeAdsDesc),
              const SizedBox(height: 8),
              if (removed)
                Text(l10n.removeAdsOwned)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      key: const Key('remove-ads-buy'),
                      onPressed: () async {
                        await ref
                            .read(purchaseServiceProvider)
                            .buy(ProductId.removeAds);
                        _refresh();
                      },
                      child: Text(l10n.removeAdsButton),
                    ),
                    TextButton(
                      key: const Key('restore-purchases'),
                      onPressed: () async {
                        await ref.read(purchaseServiceProvider).restorePurchases();
                        _refresh();
                      },
                      child: Text(l10n.restorePurchases),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: styles.cardTitle),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
