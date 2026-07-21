import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SFX cues (design doc §5). Asset content isn't bundled yet — Phase 7 ships
/// the plumbing; a sound designer drops matching files under
/// `assets/audio/sfx/` later and playback picks them up with no code change.
enum SfxSound { chipPlace, chipCover, boardClaim, gameWin, invalidMove }

abstract interface class AudioService {
  /// Never blocks or delays a move (design doc §5) — a missing or failing
  /// asset is swallowed silently rather than surfaced to the caller.
  Future<void> playSfx(SfxSound sound);

  Future<void> playMusic();
  Future<void> stopMusic();
}

final audioServiceProvider = Provider<AudioService>((ref) {
  // flutter_test has no real audioplayers platform channel, and constructing
  // AudioPlayer there leaks unhandled async errors from its own internal
  // init — every widget/controller test would otherwise need an explicit
  // override just to submit a move. Detect the test runner (the same
  // FLUTTER_TEST env var flutter_test itself sets) and no-op instead; tests
  // that want to verify actual SFX/music calls override this provider
  // explicitly with a recording fake.
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    return const _NullAudioService();
  }
  final service = AudioPlayersAudioService();
  ref.onDispose(service.dispose);
  return service;
});

class _NullAudioService implements AudioService {
  const _NullAudioService();

  @override
  Future<void> playSfx(SfxSound sound) async {}

  @override
  Future<void> playMusic() async {}

  @override
  Future<void> stopMusic() async {}
}

class AudioPlayersAudioService implements AudioService {
  AudioPlayersAudioService() {
    // Applies to every player made afterward. `respectSilence` covers
    // design doc §5's "music must respect the device silent switch"; SFX
    // gets the same treatment for consistency — a player who's flipped
    // silent mode almost certainly wants no sound at all from the app, not
    // silence for music but bleeps for moves. `AudioContextConfigFocus`
    // can't be `duckOthers`/`mixWithOthers` alongside `respectSilence` on
    // iOS (the platform asserts on that combination — `respectSilence`
    // already forces the `ambient` category there, which mixes with other
    // audio implicitly); `gain` is the only legal pairing.
    AudioPlayer.global.setAudioContext(
      AudioContextConfig(respectSilence: true).build(),
    );
    _music.setReleaseMode(ReleaseMode.loop);
  }

  final AudioPlayer _music = AudioPlayer();
  final Map<SfxSound, AudioPlayer> _sfxPlayers = {
    for (final sound in SfxSound.values) sound: AudioPlayer(),
  };

  static const _sfxAssets = {
    SfxSound.chipPlace: 'audio/sfx/chip_place.wav',
    SfxSound.chipCover: 'audio/sfx/chip_cover.wav',
    SfxSound.boardClaim: 'audio/sfx/board_claim.wav',
    SfxSound.gameWin: 'audio/sfx/game_win.wav',
    SfxSound.invalidMove: 'audio/sfx/invalid_move.wav',
  };
  static const _musicAsset = 'audio/music/theme_loop.mp3';

  @override
  Future<void> playSfx(SfxSound sound) async {
    try {
      final player = _sfxPlayers[sound]!;
      await player.stop();
      await player.play(AssetSource(_sfxAssets[sound]!));
    } catch (_) {
      // Asset not bundled yet, or platform playback failure — never let a
      // sound problem interrupt a move.
    }
  }

  @override
  Future<void> playMusic() async {
    try {
      await _music.play(AssetSource(_musicAsset));
    } catch (_) {
      // No-op: same rationale as playSfx.
    }
  }

  @override
  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {
      // No-op.
    }
  }

  Future<void> dispose() async {
    await _music.dispose();
    for (final player in _sfxPlayers.values) {
      await player.dispose();
    }
  }
}
