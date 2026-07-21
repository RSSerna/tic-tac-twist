import 'package:meta/meta.dart';

/// How a chip's level is rendered. The concentric-band mechanic itself
/// (design doc §2.3: level = a countable, non-colour marker) never changes
/// between skins — only its geometry does (design doc §2.6: "chip form
/// (rings → dolls, stones, tiles)").
enum ChipForm { rings, dolls }

/// A cosmetic skin (design doc §2.6 / product doc §2.2). Chips, boards, and
/// backgrounds are all in scope per the docs; this phase's one premium skin
/// varies chip form only — palette, board, and background stay the
/// turned-wood defaults (`GameColors.baseSkin`) so as not to redo the Phase 4
/// accessibility/contrast pass for values nothing here actually requires
/// changing yet. The model itself doesn't prevent a future skin from varying
/// those too.
@immutable
class GameSkin {
  const GameSkin({required this.id, required this.chipForm});

  /// Stable identity, persisted in [SkinService] — never shown to players.
  final String id;

  final ChipForm chipForm;

  /// Free default (design doc §2: "turned wood" direction). Always
  /// unlocked — never stored in [SkinService.unlockedSkinIds].
  static const turnedWood = GameSkin(id: 'turned_wood', chipForm: ChipForm.rings);

  /// The one premium set this phase ships (roadmap Phase 8: "base free set
  /// plus at least one premium set"). Derived from the nesting-doll origin
  /// the design doc calls out by name (§2). Achievement-unlocked this phase
  /// — real purchases are Phase 9.
  static const nestingDolls = GameSkin(id: 'nesting_dolls', chipForm: ChipForm.dolls);

  static const values = [turnedWood, nestingDolls];
}
