import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/game_session.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/tutorial_progress_service.dart';
import '../../theme/tokens.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GameScreen()),
      );
    } else {
      await controller.discardSavedGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            key: const Key('open-skins'),
            icon: const Icon(Icons.palette),
            tooltip: l10n.skinsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SkinsScreen()),
            ),
          ),
          IconButton(
            key: const Key('open-stats'),
            icon: const Icon(Icons.bar_chart),
            tooltip: l10n.statsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: textTheme.displayMedium?.copyWith(color: colors.ink),
            ),
            Text(
              l10n.homeTagline,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: colors.neutral),
            ),
            const SizedBox(height: 32),
            for (final mode in GameMode.values) ...[
              _ModeCard(mode: mode),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
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
  const _ModeCard({required this.mode});

  final GameMode mode;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // Triggered automatically the first time a mode is opened (design doc
    // §7); once completed (or explicitly skipped), opening the mode goes
    // straight to sub-mode select from then on.
    final completed =
        await ref.read(tutorialProgressServiceProvider).isCompleted(mode);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => completed ? SubModeScreen(mode: mode) : TutorialScreen(mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

    final description = switch (mode) {
      GameMode.stackStatic => l10n.modeStackStaticDesc,
      GameMode.stackMovable => l10n.modeStackMovableDesc,
      GameMode.ultimate => l10n.modeUltimateDesc,
    };

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: Key('mode-${mode.name}'),
        borderRadius: BorderRadius.circular(4),
        onTap: () => _onTap(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_modeName(l10n, mode),
                  style: textTheme.titleLarge?.copyWith(color: colors.ink)),
              const SizedBox(height: 4),
              Text(description,
                  style:
                      textTheme.bodyMedium?.copyWith(color: colors.neutral)),
            ],
          ),
        ),
      ),
    );
  }
}
