import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/services/age_gate_service.dart';
import 'package:nested_game/services/ads_service.dart';
import 'package:nested_game/services/analytics_service.dart';
import 'package:nested_game/services/audio_service.dart';
import 'package:nested_game/services/purchase_service.dart';
import 'package:nested_game/services/tutorial_progress_service.dart';
import 'package:nested_game/ui/widgets/app_glyph.dart';

/// Finds one of the project's own SVG icons (`AppIcons`) by its asset path.
///
/// `find.byIcon` only matches Material's `IconData`, so it silently finds
/// nothing once a glyph has been replaced by a drawn one — which is exactly
/// how a test asserting "the lock is showing" turns into a test asserting
/// nothing at all.
Finder findGlyph(String asset) => find.byWidgetPredicate(
  (widget) => widget is AppGlyph && widget.asset == asset,
  description: 'AppGlyph($asset)',
);

/// Marks every mode's tutorial as completed in whatever mock
/// shared_preferences store is currently active. Call after
/// `SharedPreferences.setMockInitialValues({})` in any test that navigates
/// through mode select expecting normal play, not the tutorial trigger —
/// which is everything except the tutorial's own tests.
Future<void> markAllTutorialsCompleted() async {
  final service = SharedPreferencesTutorialProgressService();
  for (final mode in GameMode.values) {
    await service.markCompleted(mode);
  }
}

/// Answers the neutral age screen in whatever mock shared_preferences store
/// is currently active, so pumping `NestedApp` goes straight to Home instead
/// of stopping on the age gate — every test except the age gate's own.
Future<void> markAgeGateAnswered({bool isChild = false}) async {
  await SharedPreferencesAgeGateService().setIsChild(isChild);
}

/// Records every call instead of touching a real platform channel — the
/// default `audioServiceProvider` already no-ops under `flutter test` (see
/// its doc comment), so this is only needed by tests that actually assert on
/// which sounds played or whether music started/stopped.
class FakeAudioService implements AudioService {
  final List<SfxSound> sfxPlayed = [];
  bool musicPlaying = false;

  @override
  Future<void> playSfx(SfxSound sound) async {
    sfxPlayed.add(sound);
  }

  @override
  Future<void> playMusic() async {
    musicPlaying = true;
  }

  @override
  Future<void> stopMusic() async {
    musicPlaying = false;
  }
}

/// Records calls instead of touching a real platform channel — the default
/// `adsServiceProvider` already no-ops under `flutter test` (see its doc
/// comment), so this is only needed by tests that assert on ad behaviour.
class FakeAdsService implements AdsService {
  bool? lastIsChild;
  int showCount = 0;
  bool loaded = true;

  @override
  Future<void> initialize({required bool isChild}) async {
    lastIsChild = isChild;
  }

  @override
  bool get isInterstitialReady => loaded;

  @override
  Future<void> showInterstitialIfLoaded() async {
    if (loaded) showCount++;
  }
}

/// Records calls and lets a test simulate a completed purchase via
/// [completePurchase] — the default `purchaseServiceProvider` already
/// no-ops under `flutter test` (same rationale as `FakeAdsService`).
class FakePurchaseService implements PurchaseService {
  final _controller = StreamController<ProductId>.broadcast();
  bool removed = false;
  final List<ProductId> boughtCalls = [];

  @override
  Future<bool> storeAvailable() async => true;

  @override
  Stream<ProductId> get purchases => _controller.stream;

  @override
  Future<void> buy(ProductId product) async {
    boughtCalls.add(product);
  }

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<bool> isRemoved() async => removed;

  @override
  Future<void> markRemoved() async {
    removed = true;
  }

  void completePurchase(ProductId product) => _controller.add(product);

  Future<void> dispose() => _controller.close();
}

/// Records every call — the default `analyticsServiceProvider` is already a
/// no-op, so this is only needed by tests that assert on which events fired.
class FakeAnalyticsService implements AnalyticsService {
  final List<String> events = [];

  @override
  Future<void> gameStarted({
    required GameMode mode,
    required String opponentType,
    Difficulty? difficulty,
  }) async {
    events.add('game_started:${mode.name}:$opponentType:${difficulty?.name}');
  }

  @override
  Future<void> gameEnded({
    required GameMode mode,
    required String result,
    required String endReason,
    required int moveCount,
    required Duration duration,
    required int firstPlayer,
  }) async {
    events.add('game_ended:${mode.name}:$result:$endReason:$moveCount:$firstPlayer');
  }

  @override
  Future<void> tutorialCompleted(GameMode mode) async {
    events.add('tutorial_completed:${mode.name}');
  }

  @override
  Future<void> tutorialSkipped(GameMode mode) async {
    events.add('tutorial_skipped:${mode.name}');
  }

  @override
  Future<void> chestOpened(String source) async {
    events.add('chest_opened:$source');
  }

  @override
  Future<void> adWatched(String placement) async {
    events.add('ad_watched:$placement');
  }
}
