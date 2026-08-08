import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/ads_controller.dart';
import '../../controllers/game_controller.dart';
import '../../engines/common/game_mode.dart';
import '../../controllers/game_session.dart';
import '../../controllers/skin_controller.dart';
import '../../engines/common/game_status.dart';
import '../../engines/stacking/stacking_move.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/chip_view.dart';
import '../widgets/inventory_row.dart';
import '../widgets/stacking_board.dart';
import '../widgets/ultimate_board.dart';
import '../widgets/winning_line_overlay.dart';

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

    final controller = ref.read(gameControllerProvider.notifier);

    return PopScope<void>(
      // A finished game has nothing left to abandon — the result overlay's
      // own "exit to menu" already handles that path. Only an ongoing game
      // needs the confirm guard (product doc §4: abandoning vs AI is a loss).
      canPop: session.status.isOver,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmAbandon(context, l10n, session);
        if (leave != true) return;
        await controller.abandonGame();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
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
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight;
                  final sideControls = [
                    _TurnBanner(session: session),
                    if (session.mode.isStacking && session.status.isOngoing)
                      IgnorePointer(
                        ignoring: session.isAiTurn,
                        child: const InventoryRow(),
                      ),
                    StagingBar(session: session),
                  ];
                  final board = BoardArea(session: session);

                  if (landscape) {
                    return Row(
                      children: [
                        Expanded(flex: 2, child: board),
                        Expanded(
                          flex: 1,
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
      ),
    );
  }

  Future<bool?> _confirmAbandon(
    BuildContext context,
    AppLocalizations l10n,
    GameSession session,
  ) {
    final body = session.opponents.personTwoIsAi
        ? l10n.abandonGameBodyVsAi
        : l10n.abandonGameBodyLocal;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.abandonGameTitle),
        content: Text(body),
        actions: [
          TextButton(
            key: const Key('abandon-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.abandonGameCancel),
          ),
          FilledButton(
            key: const Key('abandon-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.abandonGameConfirm),
          ),
        ],
      ),
    );
  }
}

/// The board itself, capped to a sensible maximum size so it doesn't
/// stretch edge-to-edge on tablets (design doc §1: "let boards grow to a
/// sensible maximum with margin").
class BoardArea extends StatelessWidget {
  const BoardArea({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final status = session.status;
    // Only for an actual line win (not a tiebreak/timeout/repetition
    // result, which has no three-in-a-row to point at).
    final winningLine = status.reason == EndReason.line
        ? status.winningLine
        : null;
    final colors = context.gameColors;

    return IgnorePointer(
      // Nothing for the human to tap on the AI's turn — the controller
      // already no-ops these, this just keeps the board from flickering a
      // stage preview under the cursor.
      ignoring: session.isAiTurn,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // maxWidth: 640,
              // maxHeight: 700,
              maxWidth: session.mode.isStacking ? 640 : 722,
              maxHeight: session.mode.isStacking ? 640 : 722,
            ),
            child: Stack(
              children: [
                session.mode.isStacking
                    ? const StackingBoard()
                    : const UltimateBoard(),
                if (winningLine != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: WinningLineOverlay(
                        line: winningLine,
                        color: session.personFor(status.winner!) == 1
                            ? colors.playerA
                            : colors.playerB,
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : context.gameAnimations.winLineReveal,
                      ),
                    ),
                  ),
              ],
            ),
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
    final styles = context.gameTextStyles;
    final person = session.currentPerson;
    final color = person == 1 ? colors.playerA : colors.playerB;
    final appearance =
        ref.watch(skinControllerProvider).value?.selectedSkin.appearance ??
        const PaintedAppearance(ChipForm.rings);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Wrap, not Row: a narrow landscape side panel (or Spanish's
          // longer strings, design doc §8) can leave less width than the
          // icon + text need together — reflow onto a second line instead
          // of overflowing (same reasoning as StagingBar/InventoryRow).
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: ChipView(
                  color: color,
                  ringColor: colors.surface,
                  level: 1,
                  isFirstPerson: person == 1,
                  appearance: appearance,
                ),
              ),
              Text(
                l10n.turnBanner(person),
                style: styles.cardTitle,
              ),
            ],
          ),
          if (session.aiThinking) ...[
            const SizedBox(height: 4),
            Text(
              l10n.aiThinking,
              key: const Key('ai-thinking'),
              style: styles.caption,
            ),
          ],
          if (session.turnDeadline != null) ...[
            const SizedBox(height: 4),
            _TurnTimerCountdown(deadline: session.turnDeadline!),
          ],
        ],
      ),
    );
  }
}

/// Live "seconds remaining" display for the local turn timer (design doc
/// §3.6). Ticks on its own widget-local timer rather than round-tripping
/// through [GameController] state every second — the deadline itself is
/// stamped once by the controller; only the display needs to be live.
class _TurnTimerCountdown extends StatefulWidget {
  const _TurnTimerCountdown({required this.deadline});

  final DateTime deadline;

  @override
  State<_TurnTimerCountdown> createState() => _TurnTimerCountdownState();
}

class _TurnTimerCountdownState extends State<_TurnTimerCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final styles = context.gameTextStyles;
    final remaining = widget.deadline.difference(DateTime.now()).inSeconds;
    return Text(
      l10n.turnTimerBanner(remaining < 0 ? 0 : remaining),
      key: const Key('turn-timer-banner'),
      style: styles.caption,
    );
  }
}

class StagingBar extends ConsumerWidget {
  const StagingBar({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final styles = context.gameTextStyles;
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
            Text(
              l10n.mustPassBanner,
              style: styles.body,
            ),
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
    final styles = context.gameTextStyles;

    final headline = status.outcome == GameOutcome.won
        ? l10n.winBanner(session.personFor(status.winner!))
        : l10n.drawBanner;
    final subtitle = switch (status.reason) {
      EndReason.repetition => l10n.resultReasonRepetition,
      EndReason.tiebreak =>
        status.outcome == GameOutcome.draw
            ? l10n.resultReasonExactTie
            : l10n.resultReasonTiebreak,
      EndReason.timeout => l10n.resultReasonTimeout,
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
              Text(
                headline,
                textAlign: TextAlign.center,
                style: styles.banner,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: styles.bodyMuted,
                ),
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
                  // Between games, never mid-game and never between the
                  // rematch tap and the new game (design doc §3.5) — this
                  // is the one place that's genuinely "between games".
                  unawaited(
                    ref
                        .read(adsControllerProvider.notifier)
                        .onReturnedToMenuAfterGame(),
                  );
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
