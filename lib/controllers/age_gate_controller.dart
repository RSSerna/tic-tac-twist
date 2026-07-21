import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/age_gate_service.dart';

/// COPPA's age-of-consent threshold — the split the neutral age screen
/// exists to establish (product doc §1).
const int childAgeCutoff = 13;

/// Null iff the player has never answered the neutral age screen.
class AgeGateController extends AsyncNotifier<bool?> {
  @override
  Future<bool?> build() => ref.read(ageGateServiceProvider).isChild();

  Future<void> answerBirthYear(int birthYear, {required int currentYear}) async {
    final isChild = (currentYear - birthYear) < childAgeCutoff;
    await ref.read(ageGateServiceProvider).setIsChild(isChild);
    state = AsyncData(isChild);
  }
}

final ageGateControllerProvider =
    AsyncNotifierProvider<AgeGateController, bool?>(AgeGateController.new);
