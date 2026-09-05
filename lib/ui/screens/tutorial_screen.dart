import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/game_session.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../tutorial/tutorial_step.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/inventory_grid.dart';
import 'game_screen.dart';
import 'sub_mode_screen.dart';
import 'tutorial_prompt_text.dart';

String _modeName(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.stackStatic => l10n.modeStackStatic,
  GameMode.stackMovable => l10n.modeStackMovable,
  GameMode.ultimate => l10n.modeUltimate,
};

/// Where the tutorial hands the player back to when it ends.
///
/// The tutorial has two entry points and they want opposite endings: opening
/// a mode for the first time is a detour *on the way* to mode select, while
/// replaying one from Settings is an errand you return from.
enum TutorialExit {
  /// Continue into mode select — the player was opening this mode.
  toModeSelect,

  /// Pop back to whatever pushed the tutorial (Settings' replay buttons).
  back,
}

/// The guided-first-game tutorial (design doc §7): the real engine, a
/// scripted opponent, and an instruction panel driven by step count. Reuses
/// [BoardArea]/[StagingBar] from [GameScreen] unmodified — the tutorial
/// restricts which moves the controller accepts, not how the board renders
/// or how a move gets staged and confirmed.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key, required this.mode, required this.exit});

  final GameMode mode;

  /// How finishing or skipping ends. Required rather than defaulted: a wrong
  /// default here is invisible until someone plays the flow.
  final TutorialExit exit;

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  @override
  void initState() {
    super.initState();
    // Riverpod forbids modifying a provider mid-build; initState runs
    // during the build phase that mounts this screen, so the actual call
    // is deferred to just after the first frame (same pattern as
    // HomeScreen's saved-game check).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gameControllerProvider.notifier).startTutorial(widget.mode);
    });
  }

  /// Ends the tutorial — from the Skip button, or Continue on the completion
  /// overlay. Both mark it done; only the destination differs.
  Future<void> _finish() async {
    await ref.read(gameControllerProvider.notifier).finishTutorial();
    if (!mounted) return;

    switch (widget.exit) {
      case TutorialExit.toModeSelect:
        // pushReplacement, not push: the tutorial shouldn't sit in the back
        // stack for the player to return to.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SubModeScreen(mode: widget.mode),
          ),
        );
      case TutorialExit.back:
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    final colors = context.gameColors;

    if (session == null || session.tutorial == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final tutorial = session.tutorial!;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Short screens (an SE-class phone in portrait) can't seat a
                // 44pt title, a full-height panel, the board, a 2×2 of chips
                // and the staging bar — the header gives up the most for the
                // least loss.
                final compact = constraints.maxHeight < 600;

                return Column(
                  children: [
                    _TutorialHeader(mode: widget.mode, compact: compact),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final landscape =
                              constraints.maxWidth > constraints.maxHeight;
                          return landscape
                              ? _LandscapeLayout(
                                  session: session,
                                  step: tutorial.currentStep,
                                  onSkip: _finish,
                                )
                              : _PortraitLayout(
                                  session: session,
                                  step: tutorial.currentStep,
                                  onSkip: _finish,
                                );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            if (tutorial.isComplete)
              _TutorialCompleteOverlay(
                step: tutorial.currentStep as TutorialComplete,
                onContinue: _finish,
              ),
          ],
        ),
      ),
    );
  }
}

/// Centred title with the mode underneath. Nothing else — Skip sits with
/// the instructions, so the title can own the full width.
class _TutorialHeader extends StatelessWidget {
  const _TutorialHeader({required this.mode, required this.compact});

  final GameMode mode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final styles = context.gameTextStyles;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, 0),
      child: Column(
        children: [
          Text(
            l10n.tutorialTitle,
            style: compact ? styles.screenTitle : styles.display,
          ),
          // The mode name is the first thing to go when height is scarce —
          // the player just tapped that mode to get here.
          if (!compact) Text(_modeName(l10n, mode), style: styles.subtitle),
        ],
      ),
    );
  }
}

/// Leaving the tutorial. Lives with the instructions rather than in the
/// header: it belongs to the guidance, and the header's job is the title.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return PillActionButton(
      key: const Key('skip-tutorial'),
      label: AppLocalizations.of(context).tutorialSkip,
      onPressed: onSkip,
    );
  }
}

/// Inventory left, board centre, instructions right — the mockup's layout.
class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.session,
    required this.step,
    required this.onSkip,
  });

  final GameSession session;
  final TutorialStep step;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // The staging bar sits below this Row rather than inside the board
          // column, so the Row's height *is* the board's band. That's what
          // lets the flanks line up against the board instead of against a
          // column that also holds the confirm/cancel controls.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The board is given exactly the width it will draw at, rather
              // than a slot it floats inside. That's what makes the flanks
              // the *real* space either side of it: give the board a wider
              // slot and the panel ends up centred on the slot instead of on
              // the gap the player actually sees.
              //
              // Both boards are square (`AspectRatio(1)`) inside BoardArea's
              // padding and size cap, so the drawn side is whichever of those
              // three limits bites first. The 224 floor is the inventory: a
              // 2×2 of 92pt tiles plus margins is 208pt wide.
              const minFlank = 224.0;
              final boardSide = [
                constraints.maxWidth - minFlank * 2 - kBoardPadding * 2,
                constraints.maxHeight - kBoardPadding * 2,
                kMaxBoardSize(stacking: session.mode.isStacking),
              ].reduce((a, b) => a < b ? a : b);
              final boardBox = boardSide + kBoardPadding * 2;

              // BoardArea centres the board vertically, so its top edge sits
              // half the leftover height down. The instruction panel starts
              // there instead of at the top of the row.
              final boardTop = ((constraints.maxHeight - boardSide) / 2).clamp(
                0.0,
                constraints.maxHeight,
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Equal flexes keep the board centred on the screen; each
                  // flank is then exactly the space beside it. Ultimate keeps
                  // its (empty) left flank for the same reason — dropping it
                  // would shunt the board sideways.
                  Expanded(
                    // Centred against this row, whose height is the board's
                    // band, so the chips sit level with the board's middle.
                    //
                    // The inner padding leans the content toward the board by
                    // BoardArea's own padding: this flank stops at the padded
                    // box, but the gap the player sees runs to the drawn
                    // board's edge, half a padding further in.
                    child: session.mode.isStacking
                        ? const Padding(
                            padding: EdgeInsets.only(left: kBoardPadding),
                            child: Center(child: InventoryGrid()),
                          )
                        : const SizedBox.shrink(),
                  ),
                  SizedBox(
                    width: boardBox,
                    child: BoardArea(session: session),
                  ),
                  Expanded(
                    child: Padding(
                      // Centres the panel in the gap beside the board — the
                      // extra 12 on the right offsets BoardArea's padding,
                      // which sits inside this flank's left edge (see the
                      // left flank for the same correction).
                      padding: EdgeInsets.fromLTRB(
                        12,
                        boardTop,
                        12 + kBoardPadding,
                        0,
                      ),
                      child: Column(
                        children: [
                          Flexible(child: _InstructionPanel(step: step)),
                          const SizedBox(height: 12),
                          _SkipButton(onSkip: onSkip),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        StagingBar(session: session),
      ],
    );
  }
}

/// Instructions above, board below, inventory under it.
class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.session,
    required this.step,
    required this.onSkip,
  });

  final GameSession session;
  final TutorialStep step;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 620;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    // Capped, because the panel sizes itself to its text and
                    // a long prompt would otherwise push the board, the
                    // inventory and the staging bar off the bottom. Past the
                    // cap the text scrolls inside the panel instead.
                    constraints: BoxConstraints(
                      // Floored as well as capped: below ~150 the pinned
                      // Next button has nowhere to sit, and a message step
                      // becomes unadvanceable.
                      maxHeight: [
                        constraints.maxHeight * (short ? 0.24 : 0.3),
                        150.0,
                      ].reduce((a, b) => a > b ? a : b),
                    ),
                    child: _InstructionPanel(step: step),
                  ),
                  const SizedBox(height: 8),
                  // Below the panel rather than beside it: on a narrow screen
                  // a Skip pill sharing the row starves the panel of width
                  // and the prompt wraps to one character per line.
                  _SkipButton(onSkip: onSkip),
                ],
              ),
            ),
            Expanded(child: BoardArea(session: session)),
            if (session.mode.isStacking) InventoryGrid(compact: short),
            StagingBar(session: session),
          ],
        );
      },
    );
  }
}

/// The instruction card: what to do now, and — on a step that's only a
/// message — the button that advances past it.
class _InstructionPanel extends ConsumerWidget {
  const _InstructionPanel({required this.step});

  final TutorialStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final controller = ref.read(gameControllerProvider.notifier);

    return Semantics(
      label: l10n.tutorialInstructions,
      child: Container(
        key: const Key('tutorial-prompt'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: elevations.raised,
        ),
        // Only the prompt scrolls; Next stays pinned to the bottom of the
        // card. Scrolling the whole panel let Next slide out of view on a
        // short screen, which strands the player on a message step — there's
        // nothing else on screen that advances it.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  tutorialPromptText(l10n, step.prompt),
                  style: styles.bodyLarge,
                ),
              ),
            ),
            if (step is TutorialMessage) ...[
              const SizedBox(height: 12),
              PillActionButton(
                key: const Key('tutorial-next'),
                label: l10n.tutorialNext,
                onPressed: controller.tutorialNext,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TutorialCompleteOverlay extends StatelessWidget {
  const _TutorialCompleteOverlay({
    required this.step,
    required this.onContinue,
  });

  final TutorialComplete step;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;

    return ColoredBox(
      color: colors.ink.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: elevations.raised,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tutorialPromptText(l10n, step.prompt),
                textAlign: TextAlign.center,
                style: styles.banner,
              ),
              const SizedBox(height: 20),
              PillActionButton(
                key: const Key('tutorial-continue'),
                label: l10n.tutorialContinue,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
