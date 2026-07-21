import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Crash reporting (product doc §5: "non-negotiable... without it you learn
/// about crashes from one-star reviews"). The doc frames the backend as an
/// open choice ("Crashlytics or Sentry") — this is deliberately a skeleton
/// for *both*, not a commitment to either: [NoOpCrashReportingService] is
/// the active default, and [CrashlyticsCrashReportingService] /
/// [SentryCrashReportingService] are real, ready-to-finish implementations
/// that need a configured backend project before they can be switched in
/// (see each class's doc comment for exactly what's left to do).
abstract interface class CrashReportingService {
  /// Call once, before anything else touches this service.
  Future<void> initialize();

  Future<void> recordError(Object error, StackTrace? stackTrace, {bool fatal = false});
  Future<void> recordFlutterError(FlutterErrorDetails details);

  /// A breadcrumb — context logged alongside the *next* crash, not an event
  /// on its own (see `AnalyticsService` for gameplay events instead).
  Future<void> log(String message);
}

/// Active by default (see class doc comment) until a backend is configured
/// and wired in via an override of this provider.
final crashReportingServiceProvider =
    Provider<CrashReportingService>((ref) => const NoOpCrashReportingService());

class NoOpCrashReportingService implements CrashReportingService {
  const NoOpCrashReportingService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recordError(Object error, StackTrace? stackTrace, {bool fatal = false}) async {}

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {}

  @override
  Future<void> log(String message) async {}
}
