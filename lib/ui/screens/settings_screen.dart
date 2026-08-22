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
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/buttons/pill_dropdown.dart';
import '../widgets/panel_header.dart';
import 'tutorial_screen.dart';

String _modeName(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.stackStatic => l10n.modeStackStatic,
  GameMode.stackMovable => l10n.modeStackMovable,
  GameMode.ultimate => l10n.modeUltimate,
};

/// Design doc §10: reset stats, replay tutorial, sound toggles, language,
/// local turn timer.
///
/// Laid out as a full-bleed panel — its own header with a close button rather
/// than an `AppBar`, and label-left/control-right rows on the bare `ground`
/// instead of section cards.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final settings = ref.watch(settingsControllerProvider).value;
    final settingsController = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              closeKey: const Key('close-settings'),
              icon: Icon(
                Icons.settings,
                size: 34,
                color: context.gameColors.neutral,
              ),
              title: l10n.settingsTitle,
              subtitle: l10n.settingsSubtitle,
            ),
            Expanded(
              child: ListView(
                // Full screen width, inset only by a horizontal gutter —
                // rows read as a single column of settings rather than a
                // centred card.
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                children: [
                  _SettingRow(
                    label: l10n.settingsSfxLabel,
                    control: _SettingSwitch(
                      switchKey: const Key('sfx-toggle'),
                      value: settings?.sfxEnabled ?? true,
                      onChanged: settingsController.setSfxEnabled,
                    ),
                  ),
                  _SettingRow(
                    label: l10n.settingsMusicLabel,
                    control: _SettingSwitch(
                      switchKey: const Key('music-toggle'),
                      value: settings?.musicEnabled ?? true,
                      onChanged: settingsController.setMusicEnabled,
                    ),
                  ),
                  const _RowDivider(),

                  // One row per mode rather than the mockup's single
                  // "Repeat tutorial" button: there are three separate
                  // tutorials, and a lone button couldn't say which.
                  _SectionLabel(l10n.settingsReplayTutorialHeading),
                  for (final mode in GameMode.values)
                    _SettingRow(
                      label: _modeName(l10n, mode),
                      control: PillActionButton(
                        key: Key('replay-tutorial-${mode.name}'),
                        label: l10n.settingsReplayAction,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TutorialScreen(mode: mode),
                          ),
                        ),
                      ),
                    ),
                  const _RowDivider(),

                  _SettingRow(
                    label: l10n.settingsLanguageHeading,
                    control: PillDropdown<String?>(
                      key: const Key('language-picker'),
                      value: settings?.languageCode,
                      onChanged: settingsController.setLanguageCode,
                      items: [
                        DropdownMenuItem(
                          key: const Key('language-system'),
                          value: null,
                          child: Text(l10n.languageSystem),
                        ),
                        DropdownMenuItem(
                          key: const Key('language-en'),
                          value: 'en',
                          child: Text(l10n.languageEnglish),
                        ),
                        DropdownMenuItem(
                          key: const Key('language-es'),
                          value: 'es',
                          child: Text(l10n.languageSpanish),
                        ),
                      ],
                    ),
                  ),
                  _SettingRow(
                    label: l10n.settingsTurnTimerHeading,
                    control: PillDropdown<TurnTimerPreset>(
                      key: const Key('turn-timer-picker'),
                      value: settings?.turnTimer,
                      onChanged: (value) {
                        if (value != null) {
                          settingsController.setTurnTimer(value);
                        }
                      },
                      items: [
                        for (final preset in TurnTimerPreset.values)
                          DropdownMenuItem(
                            key: Key('turn-timer-${preset.name}'),
                            value: preset,
                            child: Text(
                              preset == TurnTimerPreset.off
                                  ? l10n.turnTimerOff
                                  : l10n.turnTimerSeconds(preset.seconds!),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _RowDivider(),

                  _SettingRow(
                    label: l10n.settingsResetStats,
                    control: PillActionButton(
                      key: const Key('reset-stats'),
                      label: l10n.settingsReset,
                      onPressed: () => _confirmResetStats(context, ref),
                    ),
                  ),
                  // Web is inherently ad-free and purchase-free (design
                  // doc §9) — AdMob and in_app_purchase have no web
                  // implementation, so there's nothing to remove and
                  // nothing to buy there.
                  if (!kIsWeb) ...[
                    const _RowDivider(),
                    const _RemoveAdsSection(),
                  ],
                ],
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsResetStatsDone)));
  }
}

/// A label on the left, its control on the right.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.control});

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final styles = context.gameTextStyles;
    // Deliberately a step below the section headings above them, so a group
    // of rows reads as belonging to its heading rather than competing with it.
    final text = Text(label, style: styles.cardTitle);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A long translated label and a wide control can't share a line on
          // a phone — Spanish's turn-timer row is the worst case (design
          // system §8). Stack them rather than squeezing the label into a
          // column of one character per line.
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 8), control],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 16),
              Flexible(child: control),
            ],
          );
        },
      ),
    );
  }
}

/// Heading over a group of related rows.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: context.gameTextStyles.screenTitle),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 32,
      color: context.gameColors.neutral.withValues(alpha: 0.3),
    );
  }
}

/// A [Switch] painted from the palette rather than Material's defaults, so it
/// reads as the same family as the pills beside it.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.switchKey,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;

    return Switch(
      key: switchKey,
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStatePropertyAll(colors.surface),
      // `ink`, not `playerA`: indigo is Player 1's colour and carries that
      // meaning everywhere else in the app — borrowing it for a generic UI
      // control would say something the control doesn't mean.
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.ink
            : colors.neutral.withValues(alpha: 0.4),
      ),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
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
    final styles = context.gameTextStyles;

    return FutureBuilder<bool>(
      future: _removed,
      builder: (context, snapshot) {
        final removed = snapshot.data ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(l10n.removeAdsTitle),
            Text(l10n.removeAdsDesc, style: styles.bodyMuted),
            const SizedBox(height: 12),
            if (removed)
              Text(l10n.removeAdsOwned, style: styles.body)
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PillActionButton(
                    key: const Key('remove-ads-buy'),
                    label: l10n.removeAdsButton,
                    onPressed: () async {
                      await ref
                          .read(purchaseServiceProvider)
                          .buy(ProductId.removeAds);
                      _refresh();
                    },
                  ),
                  TextButton(
                    key: const Key('restore-purchases'),
                    onPressed: () async {
                      await ref
                          .read(purchaseServiceProvider)
                          .restorePurchases();
                      _refresh();
                    },
                    child: Text(l10n.restorePurchases),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
