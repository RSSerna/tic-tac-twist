import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/game_mode.dart';
import '../../controllers/game_session.dart';
import '../../engines/common/game_status.dart';
import '../../engines/stacking/stacking_move.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../widgets/chip_view.dart';
import '../widgets/inventory_row.dart';
import '../widgets/stacking_board.dart';
import '../widgets/ultimate_board.dart';

/// Shared game-screen skeleton: turn banner, mode-specific board widget
/// (swappable — skins and boards never touch game logic), staging controls,
/// and the result overlay with one-tap rematch.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    if (session == null) {
      // Exited (or hot-reloaded into a dead route): nothing to show.
      return const Scaffold(body: SizedBox.shrink());
    }

    final modeName = switch (session.mode) {
      GameMode.stackStatic => l10n.modeStackStatic,
      GameMode.stackMovable => l10n.modeStackMovable,
      GameMode.ultimate => l10n.modeUltimate,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(modeName),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TurnBanner(session: session),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: session.mode.isStacking
                          ? const StackingBoard()
                          : const UltimateBoard(),
                    ),
                  ),
                ),
                if (session.mode.isStacking && session.status.isOngoing)
                  const InventoryRow(),
                _StagingBar(session: session),
              ],
            ),
            if (session.status.isOver) _ResultOverlay(session: session),
          ],
        ),
      ),
    );
  }
}

class _TurnBanner extends ConsumerWidget {
  const _TurnBanner({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final person = session.currentPerson;
    final color = person == 1 ? colors.playerA : colors.playerB;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: ChipView(
              color: color,
              ringColor: colors.surface,
              level: 1,
              isFirstPerson: person == 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.turnBanner(person),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

class _StagingBar extends ConsumerWidget {
  const _StagingBar({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final controller = ref.read(gameControllerProvider.notifier);

    if (session.status.isOver) return const SizedBox(height: 64);

    final mustPass = controller.mustPass;
    final stagedPass = session.stagedMove is PassMove;

    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mustPass && !stagedPass) ...[
            Text(l10n.mustPassBanner,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.ink)),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('pass'),
              onPressed: () => controller.stageMove(const PassMove()),
              child: Text(l10n.passTurn),
            ),
          ],
          if (session.stagedMove != null) ...[
            FilledButton(
              key: const Key('confirm'),
              onPressed: controller.commitStagedMove,
              child: Text(l10n.confirmMove),
            ),
            const SizedBox(width: 12),
            TextButton(
              key: const Key('cancel'),
              onPressed: controller.clearSelection,
              child: Text(l10n.cancel),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultOverlay extends ConsumerWidget {
  const _ResultOverlay({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final controller = ref.read(gameControllerProvider.notifier);
    final status = session.status;
    final textTheme = Theme.of(context).textTheme;

    final headline = status.outcome == GameOutcome.won
        ? l10n.winBanner(session.personFor(status.winner!))
        : l10n.drawBanner;
    final subtitle = switch (status.reason) {
      EndReason.repetition => l10n.resultReasonRepetition,
      EndReason.tiebreak => status.outcome == GameOutcome.draw
          ? l10n.resultReasonExactTie
          : l10n.resultReasonTiebreak,
      _ => null,
    };

    return ColoredBox(
      color: colors.ink.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headline,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(color: colors.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style:
                        textTheme.bodyMedium?.copyWith(color: colors.neutral)),
              ],
              const SizedBox(height: 20),
              // Rematch is the primary action, never blocked (design §3.5).
              FilledButton(
                key: const Key('rematch'),
                onPressed: controller.rematch,
                child: Text(l10n.rematch),
              ),
              TextButton(
                key: const Key('exit'),
                onPressed: () {
                  controller.exitGame();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(l10n.exitToMenu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
