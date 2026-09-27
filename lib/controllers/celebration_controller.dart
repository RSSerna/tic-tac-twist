import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../services/celebration_service.dart';
import '../theme/celebration.dart';

@immutable
class CelebrationState {
  const CelebrationState({
    required this.selectedId,
    required this.unlockedIds,
    this.fragmentCounts = const {},
  });

  final String selectedId;

  /// Purchased celebrations. Free ones are implicitly unlocked and never
  /// appear here (see [isUnlocked]).
  final Set<String> unlockedIds;

  /// Fragments collected so far toward each fragment-gated celebration
  /// (`Celebration.fragmentsRequired`), keyed by [Celebration.id]. Absent = 0.
  final Map<String, int> fragmentCounts;

  /// Falls back to the default rather than throwing: a persisted id outlives
  /// any catalogue change that retires one.
  Celebration get selected => Celebration.values.firstWhere(
    (c) => c.id == selectedId,
    orElse: () => Celebration.defaultChoice,
  );

  bool isUnlocked(Celebration celebration) =>
      celebration.free || unlockedIds.contains(celebration.id);
}

/// Owns which celebration is equipped and which are unlocked (same pattern as
/// [SkinController]).
class CelebrationController extends AsyncNotifier<CelebrationState> {
  @override
  Future<CelebrationState> build() async {
    final service = ref.read(celebrationServiceProvider);
    return CelebrationState(
      selectedId: await service.selectedId(),
      unlockedIds: await service.unlockedIds(),
      fragmentCounts: await service.fragmentCounts(),
    );
  }

  /// No-ops on a locked celebration — the UI reflects it, but the controller
  /// is the actual gate.
  Future<void> select(Celebration celebration) async {
    final current = await future;
    if (!current.isUnlocked(celebration)) return;
    await ref.read(celebrationServiceProvider).setSelectedId(celebration.id);
    state = AsyncData(
      CelebrationState(
        selectedId: celebration.id,
        unlockedIds: current.unlockedIds,
        fragmentCounts: current.fragmentCounts,
      ),
    );
  }

  /// Returns true iff [celebration] was newly unlocked. Here for the purchase
  /// route to call once store products exist.
  Future<bool> unlock(Celebration celebration) async {
    final current = await future;
    if (current.isUnlocked(celebration)) return false;
    await ref.read(celebrationServiceProvider).unlock(celebration.id);
    state = AsyncData(
      CelebrationState(
        selectedId: current.selectedId,
        unlockedIds: {...current.unlockedIds, celebration.id},
        fragmentCounts: current.fragmentCounts,
      ),
    );
    return true;
  }

  /// Adds [amount] fragments toward unlocking [celebration]; auto-unlocks
  /// via [unlock] once the total reaches [Celebration.fragmentsRequired].
  /// No-ops (returns null) if [celebration] isn't fragment-gated or is
  /// already unlocked. Mirrors `SkinController.addFragments`.
  Future<({int totalAfter, bool unlockedNow})?> addFragments(
    Celebration celebration,
    int amount,
  ) async {
    final current = await future;
    final required = celebration.fragmentsRequired;
    if (required == null || current.isUnlocked(celebration)) return null;

    final total = (current.fragmentCounts[celebration.id] ?? 0) + amount;
    await ref
        .read(celebrationServiceProvider)
        .setFragmentCount(celebration.id, total);
    state = AsyncData(
      CelebrationState(
        selectedId: current.selectedId,
        unlockedIds: current.unlockedIds,
        fragmentCounts: {...current.fragmentCounts, celebration.id: total},
      ),
    );

    final unlockedNow = total >= required;
    if (unlockedNow) await unlock(celebration);
    return (totalAfter: total, unlockedNow: unlockedNow);
  }
}

final celebrationControllerProvider =
    AsyncNotifierProvider<CelebrationController, CelebrationState>(
      CelebrationController.new,
    );
