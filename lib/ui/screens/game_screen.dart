import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../engines/common/game_mode.dart';
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
            LayoutBuilder(
              builder: (context, constraints) {
                // Both orientations (design doc §1): landscape puts the
                // board and controls side by side rather than fighting
                // over limited vertical height.
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final sideControls = [
                  _TurnBanner(session: session),
                  if (session.mode.isStacking && session.status.isOngoing)
                    IgnorePointer(
                      ignoring: session.isAiTurn,
                      child: const InventoryRow(),
                    ),
                  _StagingBar(session: session),
                ];
                final board = _BoardArea(session: session);

                if (landscape) {
                  return Row(
                    children: [
                      Expanded(child: board),
                      SizedBox(
                        width: 300,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: sideControls,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    ...sideControls.take(1),
                    Expanded(child: board),
                    ...sideControls.skip(1),
                  ],
                );
              },
            ),
            if (session.status.isOver) _ResultOverlay(session: session),
          ],
        ),
      ),
    );
  }
}

/// The board itself, capped to a sensible maximum size so it doesn't
/// stretch edge-to-edge on tablets (design doc §1: "let boards grow to a
/// sensible maximum with margin").
class _BoardArea extends StatelessWidget {
  const _BoardArea({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Nothing for the human to tap on the AI's turn — the controller
      // already no-ops these, this just keeps the board from flickering a
      // stage preview under the cursor.
      ignoring: session.isAiTurn,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
            child: session.mode.isStacking
                ? const StackingBoard()
                : const UltimateBoard(),
          ),
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
      child: Column(
        children: [
          Row(
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
          if (session.aiThinking) ...[
            const SizedBox(height: 4),
            Text(
              l10n.aiThinking,
              key: const Key('ai-thinking'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.neutral),
            ),
          ],
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

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      // Wrap, not Row: this bar sits either at full screen width (portrait)
      // or squeezed into a narrow side panel (landscape) — it must reflow
      // rather than overflow either way.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (mustPass && !stagedPass) ...[
            Text(l10n.mustPassBanner,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.ink)),
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
