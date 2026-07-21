import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporting_service.dart';

/// Firebase Crashlytics backend for [CrashReportingService].
///
/// Not the active default yet (see `crash_reporting_service.dart`). Left to
/// finish before switching this in:
/// 1. Create a Firebase project and add `google-services.json` (Android) /
///    `GoogleService-Info.plist` (iOS) to the platform folders.
/// 2. Apply the Firebase Gradle plugin in `android/build.gradle` and
///    `android/app/build.gradle` (and the Firebase Cocoapod for iOS, handled
///    automatically by `firebase_core`'s podspec).
/// 3. Override `crashReportingServiceProvider` with
///    `CrashlyticsCrashReportingService()` in `main()`.
class CrashlyticsCrashReportingService implements CrashReportingService {
  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
    // Crashlytics' own recommended fatal-error hook, layered under
    // whatever main() has already set for FlutterError.onError.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  @override
  Future<void> recordError(Object error, StackTrace? stackTrace, {bool fatal = false}) =>
      FirebaseCrashlytics.instance
          .recordError(error, stackTrace, fatal: fatal);

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) =>
      FirebaseCrashlytics.instance.recordFlutterError(details);

  @override
  Future<void> log(String message) => FirebaseCrashlytics.instance.log(message);
}
