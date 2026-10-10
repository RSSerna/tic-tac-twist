import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/board_skin_service.dart';
import '../theme/board_skin.dart';

@immutable
class BoardSkinState {
  const BoardSkinState({required this.selectedId, required this.unlockedIds});

  final String selectedId;

  /// Purchased boards. Free ones are implicitly unlocked and never appear
  /// here (see [isUnlocked]).
  final Set<String> unlockedIds;

  bool isUnlocked(BoardSkin skin) => skin.free || unlockedIds.contains(skin.id);

  /// What the board actually wears. Falls back to the default rather than
  /// throwing for a persisted id that no longer exists, *or* one that isn't
  /// unlocked (a restore that hasn't landed yet, a refunded purchase) — a
  /// board the player doesn't own must never render.
  BoardSkin get selected {
    for (final skin in BoardSkin.values) {
      if (skin.id == selectedId && isUnlocked(skin)) return skin;
    }
    return BoardSkin.defaultChoice;
  }
}

/// Owns which board is equipped and which purchased boards are unlocked
/// (same pattern as `CelebrationController`).
class BoardSkinController extends AsyncNotifier<BoardSkinState> {
  @override
  Future<BoardSkinState> build() async {
    final service = ref.read(boardSkinServiceProvider);
    return BoardSkinState(
      selectedId: await service.selectedId(),
      unlockedIds: await service.unlockedIds(),
    );
  }

  /// No-ops on a locked board — the UI reflects it, but the controller is the
  /// actual gate.
  Future<void> select(BoardSkin skin) async {
    final current = await future;
    if (!current.isUnlocked(skin)) return;
    await ref.read(boardSkinServiceProvider).setSelectedId(skin.id);
    state = AsyncData(
      BoardSkinState(selectedId: skin.id, unlockedIds: current.unlockedIds),
    );
  }

  /// Returns true iff [skin] was newly unlocked. Called by the purchase route
  /// (`MonetizationController`), which fires for restored purchases too.
  Future<bool> unlock(BoardSkin skin) async {
    final current = await future;
    if (current.isUnlocked(skin)) return false;
    await ref.read(boardSkinServiceProvider).unlock(skin.id);
    state = AsyncData(
      BoardSkinState(
        selectedId: current.selectedId,
        unlockedIds: {...current.unlockedIds, skin.id},
      ),
    );
    return true;
  }
}

final boardSkinControllerProvider =
    AsyncNotifierProvider<BoardSkinController, BoardSkinState>(
      BoardSkinController.new,
    );
