import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../tutorial/tutorial_step.dart';
import '../widgets/inventory_row.dart';
import 'game_screen.dart';
import 'sub_mode_screen.dart';
import 'tutorial_prompt_text.dart';

String _modeName(AppLocalizations l10n, GameMode mode) => switch (mode) {
      GameMode.stackStatic => l10n.modeStackStatic,
      GameMode.stackMovable => l10n.modeStackMovable,
      GameMode.ultimate => l10n.modeUltimate,
    };

/// The guided-first-game tutorial (design doc §7): the real engine, a
/// scripted opponent, and a prompt overlay driven by step count. Reuses
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
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    if (session == null || session.tutorial == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final tutorial = session.tutorial!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeName(l10n, widget.mode)),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
        actions: [
          TextButton(
            key: const Key('skip-tutorial'),
            onPressed: _exitToSubMode,
            child: Text(l10n.tutorialSkip, style: TextStyle(color: colors.ink)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _PromptBanner(step: tutorial.currentStep),
                Expanded(child: BoardArea(session: session)),
                if (session.mode.isStacking) const InventoryRow(),
                StagingBar(session: session),
              ],
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

class _PromptBanner extends ConsumerWidget {
  const _PromptBanner({required this.step});

  final TutorialStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final controller = ref.read(gameControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('tutorial-prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tutorialPromptText(l10n, step.prompt),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: colors.ink),
          ),
          if (step is TutorialMessage) ...[
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('tutorial-next'),
              onPressed: controller.tutorialNext,
              child: Text(l10n.tutorialNext),
            ),
          ],
        ],
      ),
    );
  }
}

class _TutorialCompleteOverlay extends StatelessWidget {
  const _TutorialCompleteOverlay({required this.step, required this.onContinue});

  final TutorialComplete step;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

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
                tutorialPromptText(l10n, step.prompt),
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('tutorial-continue'),
                onPressed: onContinue,
                child: Text(l10n.tutorialContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
