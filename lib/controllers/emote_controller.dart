import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/emote_service.dart';
import '../theme/emote.dart';

@immutable
class EmoteState {
  const EmoteState({required this.loadout, required this.unlockedIds});

  /// Equipped emotes in slot order, at most [Emote.loadoutSize] long.
  final List<Emote> loadout;

  /// Purchased emotes. Free ones are implicitly unlocked and never appear
  /// here (see [isUnlocked]).
  final Set<String> unlockedIds;

  bool isUnlocked(Emote emote) => emote.free || unlockedIds.contains(emote.id);

  bool isEquipped(Emote emote) => loadout.contains(emote);

  bool get isFull => loadout.length >= Emote.loadoutSize;
}

/// Owns the equipped-emote loadout and which emotes are unlocked, loading
/// both once and persisting every change (same pattern as [SkinController]).
class EmoteController extends AsyncNotifier<EmoteState> {
  @override
  Future<EmoteState> build() async {
    final service = ref.read(emoteServiceProvider);
    final ids = await service.loadoutIds();
    final unlocked = await service.unlockedIds();

    // Ids that no longer match an emote are dropped rather than crashing:
    // a saved loadout outlives any catalogue change that retires one.
    final loadout = <Emote>[];
    for (final id in ids) {
      final match = Emote.values.where((e) => e.id == id);
      if (match.isNotEmpty) loadout.add(match.first);
    }

    return EmoteState(
      loadout: List.unmodifiable(loadout.take(Emote.loadoutSize)),
      unlockedIds: unlocked,
    );
  }

  /// Adds [emote] to the first free slot, or removes it if already equipped.
  ///
  /// No-ops on a locked emote or a full loadout — the UI reflects both, but
  /// the controller is the actual gate (same reasoning as
  /// `SkinController.selectSkin`).
  Future<void> toggle(Emote emote) async {
    final current = await future;
    if (!current.isUnlocked(emote)) return;

    final next = [...current.loadout];
    if (next.remove(emote)) {
      await _save(current, next);
      return;
    }
    if (next.length >= Emote.loadoutSize) return;
    next.add(emote);
    await _save(current, next);
  }

  /// Empties the slot at [index]. Out-of-range indices no-op, so a stale tap
  /// on a slot that just emptied can't throw.
  Future<void> removeAt(int index) async {
    final current = await future;
    if (index < 0 || index >= current.loadout.length) return;
    await _save(current, [...current.loadout]..removeAt(index));
  }

  /// Returns true iff [emote] was newly unlocked. Here for the purchase
  /// route to call once store products exist for emotes.
  Future<bool> unlock(Emote emote) async {
    final current = await future;
    if (current.isUnlocked(emote)) return false;
    await ref.read(emoteServiceProvider).unlock(emote.id);
    state = AsyncData(
      EmoteState(
        loadout: current.loadout,
        unlockedIds: {...current.unlockedIds, emote.id},
      ),
    );
    return true;
  }

  Future<void> _save(EmoteState current, List<Emote> loadout) async {
    await ref.read(emoteServiceProvider).setLoadoutIds([
      for (final e in loadout) e.id,
    ]);
    state = AsyncData(
      EmoteState(
        loadout: List.unmodifiable(loadout),
        unlockedIds: current.unlockedIds,
      ),
    );
  }
}

final emoteControllerProvider =
    AsyncNotifierProvider<EmoteController, EmoteState>(EmoteController.new);
