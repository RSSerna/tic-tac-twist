import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/skin_service.dart';
import '../theme/skin.dart';

@immutable
class SkinState {
  const SkinState({required this.selectedId, required this.unlockedIds});

  final String selectedId;

  /// Premium skins unlocked so far — [GameSkin.turnedWood] is implicitly
  /// unlocked and never appears here (see [isUnlocked]).
  final Set<String> unlockedIds;

  GameSkin get selectedSkin => GameSkin.values.firstWhere(
        (skin) => skin.id == selectedId,
        orElse: () => GameSkin.turnedWood,
      );

  bool isUnlocked(GameSkin skin) =>
      skin.id == GameSkin.turnedWood.id || unlockedIds.contains(skin.id);
}

/// Loads persisted skin selection/unlocks once, then mutates them (same
/// pattern as [SettingsController]).
class SkinController extends AsyncNotifier<SkinState> {
  @override
  Future<SkinState> build() async {
    final service = ref.read(skinServiceProvider);
    return SkinState(
      selectedId: await service.selectedSkinId(),
      unlockedIds: await service.unlockedSkinIds(),
    );
  }

  /// No-ops if [skin] isn't unlocked — the UI should already prevent this,
  /// but the controller is the actual gate.
  ///
  /// Awaits [future] rather than reading `state.value` directly: a caller
  /// that reaches this before [build] has ever resolved (e.g. the very
  /// first thing touching this provider in a session, like an achievement
  /// unlock firing moments after a fresh game starts) would otherwise see
  /// `null` and silently no-op.
  Future<void> selectSkin(GameSkin skin) async {
    final current = await future;
    if (!current.isUnlocked(skin)) return;
    await ref.read(skinServiceProvider).setSelectedSkinId(skin.id);
    state = AsyncData(
      SkinState(selectedId: skin.id, unlockedIds: current.unlockedIds),
    );
  }

  /// Returns true iff [skin] was newly unlocked (false if already unlocked,
  /// or if it's the always-unlocked free skin). See [selectSkin]'s doc
  /// comment for why this awaits [future] instead of reading `state.value`.
  Future<bool> unlockSkin(GameSkin skin) async {
    final current = await future;
    if (current.isUnlocked(skin)) return false;
    await ref.read(skinServiceProvider).unlockSkin(skin.id);
    state = AsyncData(SkinState(
      selectedId: current.selectedId,
      unlockedIds: {...current.unlockedIds, skin.id},
    ));
    return true;
  }
}

final skinControllerProvider =
    AsyncNotifierProvider<SkinController, SkinState>(SkinController.new);
