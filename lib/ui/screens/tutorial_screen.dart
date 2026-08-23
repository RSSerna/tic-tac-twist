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

/// The guided-first-game tutorial (design doc §7): the real engine, a
/// scripted opponent, and an instruction panel driven by step count. Reuses
/// [BoardArea]/[StagingBar] from [GameScreen] unmodified — the tutorial
/// restricts which moves the controller accepts, not how the board renders
/// or how a move gets staged and confirmed.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key, required this.mode});

  final GameMode mode;

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

  Future<void> _exitToSubMode() async {
    await ref.read(gameControllerProvider.notifier).finishTutorial();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => SubModeScreen(mode: widget.mode)),
    );
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
                                  onSkip: _exitToSubMode,
                                )
                              : _PortraitLayout(
                                  session: session,
                                  step: tutorial.currentStep,
                                  onSkip: _exitToSubMode,
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
                onContinue: _exitToSubMode,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Both flanks get the same width so the board's remaining space is
        // centred on the *screen*, not on whatever the instruction panel
        // leaves over. Ultimate keeps its (empty) left slot for the same
        // reason — losing it would shunt the board sideways.
        // Floor is set by the inventory: a 2×2 of 92pt tiles plus margins is
        // 208pt, so anything under ~224 would clip it.
        final sideWidth = (constraints.maxWidth * 0.22).clamp(224.0, 320.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sideWidth,
              child: session.mode.isStacking
                  ? const Center(child: InventoryGrid())
                  : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: BoardArea(session: session)),
                  StagingBar(session: session),
                ],
              ),
            ),
            SizedBox(
              width: sideWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
                child: Column(
                  children: [
                    // Stretched rather than sized to its text, so the panel
                    // starts just under the title and runs down the side —
                    // a card floating mid-height reads as an afterthought.
                    Expanded(child: _InstructionPanel(step: step)),
                    const SizedBox(height: 12),
                    _SkipButton(onSkip: onSkip),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
                      maxHeight: constraints.maxHeight * (short ? 0.2 : 0.3),
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
        // The whole panel scrolls, not just the prompt: the layout sets this
        // card's height, and on a short screen that height can be less than
        // the text *and* the Next button need. Scrolling only the text would
        // still overflow on the button.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tutorialPromptText(l10n, step.prompt),
                style: styles.bodyLarge,
              ),
              if (step is TutorialMessage) ...[
                const SizedBox(height: 16),
                PillActionButton(
                  key: const Key('tutorial-next'),
                  label: l10n.tutorialNext,
                  onPressed: controller.tutorialNext,
                ),
              ],
            ],
          ),
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
