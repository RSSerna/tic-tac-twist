import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/skin_service.dart';
import '../theme/skin.dart';

@immutable
class SkinState {
  const SkinState({
    required this.firstPersonId,
    required this.secondPersonId,
    required this.unlockedIds,
  });

  /// The skin dressing each mark. Chosen and sold separately — the shop
  /// lists the X mark and the O mark as distinct items.
  final String firstPersonId;
  final String secondPersonId;

  /// Premium skins unlocked so far — [GameSkin.turnedWood] is implicitly
  /// unlocked and never appears here (see [isUnlocked]).
  final Set<String> unlockedIds;

  /// Falls back to the free skin rather than throwing: a persisted id
  /// outlives any catalogue change that retires one.
  static GameSkin _byId(String id) => GameSkin.values.firstWhere(
    (skin) => skin.id == id,
    orElse: () => GameSkin.turnedWood,
  );

  GameSkin skinFor({required bool isFirstPerson}) =>
      _byId(isFirstPerson ? firstPersonId : secondPersonId);

  SkinPair get pair => SkinPair(
    firstPerson: _byId(firstPersonId),
    secondPerson: _byId(secondPersonId),
  );

  bool isSelected(GameSkin skin, {required bool forFirstPerson}) =>
      skin.id == (forFirstPerson ? firstPersonId : secondPersonId);

  bool isUnlocked(GameSkin skin) =>
      skin.id == GameSkin.turnedWood.id || unlockedIds.contains(skin.id);

  SkinState _copyWith({
    String? firstPersonId,
    String? secondPersonId,
    Set<String>? unlockedIds,
  }) => SkinState(
    firstPersonId: firstPersonId ?? this.firstPersonId,
    secondPersonId: secondPersonId ?? this.secondPersonId,
    unlockedIds: unlockedIds ?? this.unlockedIds,
  );
}

/// Loads persisted skin selection/unlocks once, then mutates them (same
/// pattern as [SettingsController]).
class SkinController extends AsyncNotifier<SkinState> {
  @override
  Future<SkinState> build() async {
    final service = ref.read(skinServiceProvider);
    return SkinState(
      firstPersonId: await service.selectedSkinId(firstPerson: true),
      secondPersonId: await service.selectedSkinId(firstPerson: false),
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
  Future<void> selectSkin(GameSkin skin, {required bool forFirstPerson}) async {
    final current = await future;
    if (!current.isUnlocked(skin)) return;
    await ref
        .read(skinServiceProvider)
        .setSelectedSkinId(skin.id, firstPerson: forFirstPerson);
    state = AsyncData(
      forFirstPerson
          ? current._copyWith(firstPersonId: skin.id)
          : current._copyWith(secondPersonId: skin.id),
    );
  }

  /// Returns true iff [skin] was newly unlocked (false if already unlocked,
  /// or if it's the always-unlocked free skin). See [selectSkin]'s doc
  /// comment for why this awaits [future] instead of reading `state.value`.
  Future<bool> unlockSkin(GameSkin skin) async {
    final current = await future;
    if (current.isUnlocked(skin)) return false;
    await ref.read(skinServiceProvider).unlockSkin(skin.id);
    state = AsyncData(
      current._copyWith(unlockedIds: {...current.unlockedIds, skin.id}),
    );
    return true;
  }
}

final skinControllerProvider =
    AsyncNotifierProvider<SkinController, SkinState>(SkinController.new);
