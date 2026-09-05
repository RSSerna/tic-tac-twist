import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/game_session.dart';
import '../../controllers/settings_controller.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/tutorial_progress_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_mark.dart';
import '../widgets/buttons/circle_button_cluster.dart';
import '../widgets/buttons/circle_icon_button.dart';
import '../widgets/buttons/menu_pill_button.dart';
import 'challenges_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'skins_screen.dart';
import 'stats_screen.dart';
import 'sub_mode_screen.dart';
import 'tutorial_screen.dart';

String _modeName(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.stackStatic => l10n.modeStackStatic,
  GameMode.stackMovable => l10n.modeStackMovable,
  GameMode.ultimate => l10n.modeUltimate,
};

/// Home / mode select: the three v1 modes.
///
/// Also the resume-or-abandon checkpoint (rules doc §5): a game left
/// in-progress from a previous launch is offered back here, once, before
/// anything else is shown.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForSavedGame());
  }

  Future<void> _checkForSavedGame() async {
    final controller = ref.read(gameControllerProvider.notifier);
    final saved = await controller.peekSavedGame();
    if (saved == null || !mounted) return;

    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ResumeGameDialog(session: saved),
    );
    if (!mounted) return;

    if (resume == true) {
      controller.resumeSession(saved);
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
    } else {
      await controller.discardSavedGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Landscape phones are the tight case: ~390pt of height has to
            // hold the wordmark and three buttons. Everything shrinks
            // together rather than the layout switching shape, so the screen
            // reads the same in both orientations.
            final compact = constraints.maxHeight < 560;

            // The corner clusters run down the sides now, so on a narrow
            // screen they occupy the same band of height as the menu. Inset
            // the menu past them — symmetrically, so it stays centred even
            // though only one side has buttons at any given height.
            final sideInset = constraints.maxWidth < 640 ? 72.0 : 24.0;

            return Stack(
              children: [
                // Corner controls are stacked over the menu, not laid out
                // beside it, so the menu stays optically centred on the
                // screen instead of being pushed off-centre by them.
                Positioned.fill(
                  child: _MenuColumn(compact: compact, sideInset: sideInset),
                ),
                Positioned(top: 8, right: 8, child: _CornerControls()),
                Positioned(left: 8, bottom: 8, child: _QuickControls()),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The wordmark and the three mode buttons — the centre of the screen.
class _MenuColumn extends StatelessWidget {
  const _MenuColumn({required this.compact, required this.sideInset});

  final bool compact;

  /// Horizontal room left for the corner clusters running down the sides.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final styles = context.gameTextStyles;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        sideInset,
        compact ? 24 : 48,
        sideInset,
        compact ? 24 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          // Design doc §1: on a tablet, let things "grow to a sensible
          // maximum with margin" rather than stretching across the width.
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppMark(size: compact ? 48 : 88),
              SizedBox(height: compact ? 4 : 8),
              Text(
                l10n.appTitle,
                textAlign: TextAlign.center,
                style: compact ? styles.banner : styles.display,
              ),
              Text(
                l10n.homeTagline,
                textAlign: TextAlign.center,
                style: styles.subtitle,
              ),
              SizedBox(height: compact ? 20 : 40),
              for (final mode in GameMode.values) ...[
                _ModeCard(mode: mode, compact: compact),
                SizedBox(height: compact ? 10 : 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stats, skins, shop and settings, clustered in the top-right corner.
class _CornerControls extends StatelessWidget {
  const _CornerControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));

    return CircleButtonCluster(
      direction: Axis.horizontal,
      children: [
        CircleIconButton(
          key: const Key('open-stats'),
          icon: Icons.bar_chart,
          tooltip: l10n.statsTitle,
          onPressed: () => open(const StatsScreen()),
        ),
        CircleIconButton(
          key: const Key('open-skins'),
          icon: Icons.palette,
          tooltip: l10n.skinsTitle,
          onPressed: () => open(const SkinsScreen()),
        ),
        CircleIconButton(
          key: const Key('open-shop'),
          icon: Icons.storefront,
          tooltip: l10n.shopTitle,
          onPressed: () => open(const ShopScreen()),
        ),
        CircleIconButton(
          key: const Key('open-settings'),
          icon: Icons.settings,
          tooltip: l10n.settingsTitle,
          onPressed: () => open(const SettingsScreen()),
        ),
      ],
    );
  }
}

/// Bottom-left quick toggles. A cluster like [_CornerControls] rather than a
/// lone button, so the other shortcuts in the design have somewhere to land
/// without re-doing the corner.
class _QuickControls extends ConsumerWidget {
  const _QuickControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider).value;
    // Defaults to on while settings are still loading, matching
    // SettingsScreen — the toggle must not flicker to "muted" on launch.
    final musicOn = settings?.musicEnabled ?? true;

    return CircleButtonCluster(
      growUpwards: true,
      children: [
        // A shortcut to the setting the Settings screen owns, not a second
        // source of truth for it.
        CircleIconButton(
          key: const Key('home-music-toggle'),
          icon: musicOn ? Icons.music_note : Icons.music_off,
          tooltip: l10n.settingsMusicLabel,
          onPressed: () => ref
              .read(settingsControllerProvider.notifier)
              .setMusicEnabled(!musicOn),
        ),
        // A target, echoing both the mockup's missions glyph and the
        // concentric-ring language the chips are built on.
        CircleIconButton(
          key: const Key('open-challenges'),
          icon: Icons.track_changes,
          tooltip: l10n.challengesTitle,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChallengesScreen()),
          ),
        ),
      ],
    );
  }
}

class _ResumeGameDialog extends StatelessWidget {
  const _ResumeGameDialog({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.resumeGameTitle),
      content: Text(l10n.resumeGameBody(_modeName(l10n, session.mode))),
      actions: [
        TextButton(
          key: const Key('abandon-game'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.abandonAction),
        ),
        FilledButton(
          key: const Key('resume-game'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.resumeAction),
        ),
      ],
    );
  }
}

class _ModeCard extends ConsumerWidget {
  const _ModeCard({required this.mode, required this.compact});

  final GameMode mode;
  final bool compact;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // Triggered automatically the first time a mode is opened (design doc
    // §7); once completed (or explicitly skipped), opening the mode goes
    // straight to sub-mode select from then on.
    final completed = await ref
        .read(tutorialProgressServiceProvider)
        .isCompleted(mode);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => completed
            ? SubModeScreen(mode: mode)
            // First time in this mode: the tutorial is on the way to mode
            // select, so it continues there rather than back to Home.
            : TutorialScreen(mode: mode, exit: TutorialExit.toModeSelect),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // The mode's one-line blurb isn't shown here any more — the sub-mode
    // screen it opens already repeats it, so the menu stays uncluttered.
    return MenuPillButton(
      key: Key('mode-${mode.name}'),
      label: _modeName(l10n, mode),
      height: compact ? 56 : 84,
      onPressed: () => _onTap(context, ref),
    );
  }
}
