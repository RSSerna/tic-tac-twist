import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the neutral age screen's outcome (product doc §1.1): asked
/// once, never re-prompted. Only the classification is kept, not the birth
/// year itself — the app has no use for the exact value beyond the child /
/// non-child split, and keeping less personal data than necessary is the
/// safer default.
abstract interface class AgeGateService {
  /// Null iff the player has never answered.
  Future<bool?> isChild();
  Future<void> setIsChild(bool isChild);
}

final ageGateServiceProvider =
    Provider<AgeGateService>((ref) => SharedPreferencesAgeGateService());

class SharedPreferencesAgeGateService implements AgeGateService {
  static const _key = 'nested_game.age_gate.is_child';

  @override
  Future<bool?> isChild() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key);
  }

  @override
  Future<void> setIsChild(bool isChild) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isChild);
  }
}
