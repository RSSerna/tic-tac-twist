import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Runs once before every test in this directory (Flutter's convention for
/// this filename). GameController persists to shared_preferences on every
/// move; without a mock store, any test that plays a move would hit a real
/// platform channel that doesn't exist in the test environment.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
