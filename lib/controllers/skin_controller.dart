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
    this.firstPersonUltimateLevel,
    this.secondPersonUltimateLevel,
  });

  /// The skin dressing each mark. Chosen and sold separately — the shop
  /// lists the X mark and the O mark as distinct items.
  final String firstPersonId;
  final String secondPersonId;

  /// Premium skins unlocked so far — [GameSkin.turnedWood] is implicitly
  /// unlocked and never appears here (see [isUnlocked]).
  final Set<String> unlockedIds;

  /// The chip level the player picked for each mark in Ultimate, or null if
  /// they never picked one. What actually renders comes from
  /// [SkinPair.ultimateLevelFor], which resolves a null to the default and a
  /// glyph skin to the classic X/O — read that, not these.
  final int? firstPersonUltimateLevel;
  final int? secondPersonUltimateLevel;

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
    firstPersonUltimateLevel: firstPersonUltimateLevel,
    secondPersonUltimateLevel: secondPersonUltimateLevel,
  );

  bool isSelected(GameSkin skin, {required bool forFirstPerson}) =>
      skin.id == (forFirstPerson ? firstPersonId : secondPersonId);

  bool isUnlocked(GameSkin skin) =>
      skin.free || unlockedIds.contains(skin.id);

  /// The Ultimate levels are copied wholesale rather than via `??`: null is
  /// a real value there ("classic X/O"), so the usual omitted-means-unchanged
  /// idiom can't express clearing one. Callers that change one pass both.
  SkinState _copyWith({
    String? firstPersonId,
    String? secondPersonId,
    Set<String>? unlockedIds,
    int? firstPersonUltimateLevel,
    int? secondPersonUltimateLevel,
  }) => SkinState(
    firstPersonId: firstPersonId ?? this.firstPersonId,
    secondPersonId: secondPersonId ?? this.secondPersonId,
    unlockedIds: unlockedIds ?? this.unlockedIds,
    firstPersonUltimateLevel: firstPersonUltimateLevel,
    secondPersonUltimateLevel: secondPersonUltimateLevel,
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
      firstPersonUltimateLevel: await service.ultimateMarkLevel(
        firstPerson: true,
      ),
      secondPersonUltimateLevel: await service.ultimateMarkLevel(
        firstPerson: false,
      ),
    );
  }

  /// Picks which chip variant stands in for this mark on the Ultimate board.
  /// Ultimate has no levels of its own, so a skin whose art changes per level
  /// ([GameSkin.variesByLevel]) has to be told which one to wear there;
  /// passing null restores [kDefaultUltimateMarkLevel].
  Future<void> setUltimateMarkLevel(
    int? level, {
    required bool forFirstPerson,
  }) async {
    final current = await future;
    await ref
        .read(skinServiceProvider)
        .setUltimateMarkLevel(level, firstPerson: forFirstPerson);
    state = AsyncData(
      current._copyWith(
        firstPersonUltimateLevel: forFirstPerson
            ? level
            : current.firstPersonUltimateLevel,
        secondPersonUltimateLevel: forFirstPerson
            ? current.secondPersonUltimateLevel
            : level,
      ),
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
      // The chosen level carries across a skin change untouched: every
      // levelled skin has all four, so a choice made on one is meaningful on
      // the next, and a glyph skin simply ignores it.
      forFirstPerson
          ? current._copyWith(
              firstPersonId: skin.id,
              firstPersonUltimateLevel: current.firstPersonUltimateLevel,
              secondPersonUltimateLevel: current.secondPersonUltimateLevel,
            )
          : current._copyWith(
              secondPersonId: skin.id,
              firstPersonUltimateLevel: current.firstPersonUltimateLevel,
              secondPersonUltimateLevel: current.secondPersonUltimateLevel,
            ),
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
      current._copyWith(
        unlockedIds: {...current.unlockedIds, skin.id},
        firstPersonUltimateLevel: current.firstPersonUltimateLevel,
        secondPersonUltimateLevel: current.secondPersonUltimateLevel,
      ),
    );
    return true;
  }
}

final skinControllerProvider =
    AsyncNotifierProvider<SkinController, SkinState>(SkinController.new);
