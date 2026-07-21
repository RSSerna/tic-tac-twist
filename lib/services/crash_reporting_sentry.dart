import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporting_service.dart';

/// Sentry backend for [CrashReportingService].
///
/// Not the active default yet (see `crash_reporting_service.dart`). Left to
/// finish before switching this in:
/// 1. Create a Sentry project and put its DSN below (or read it from an
///    environment/config value — don't commit a real DSN to source control
///    if this repo is ever made public).
/// 2. Override `crashReportingServiceProvider` with
///    `SentryCrashReportingService()` in `main()`.
class SentryCrashReportingService implements CrashReportingService {
  @override
  Future<void> initialize() async {
    await SentryFlutter.init((options) {
      // TODO(setup): real Sentry DSN goes here.
      options.dsn = '';
    });
  }

  @override
  Future<void> recordError(Object error, StackTrace? stackTrace, {bool fatal = false}) =>
      Sentry.captureException(error, stackTrace: stackTrace);

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) => Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );

  @override
  Future<void> log(String message) async {
    Sentry.addBreadcrumb(Breadcrumb(message: message));
  }
}
