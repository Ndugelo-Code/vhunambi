import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vhunambi_client/core/resilience/safe_audio_orchestrator.dart';

/// Contract for playing synthesized Sketchpad loops, single-note pad taps, and
/// 24-Voice Regional Catalog vocal previews on hardware audio output.
abstract class ISketchpadAudioPlayerService {
  /// Starts looped hardware playback of a 16-step WAV buffer and invokes [onStepTick]
  /// on each 16th-note boundary (`0..15`).
  Future<void> startLoopPlayback(
    Uint8List wavBytes, {
    required int bpm,
    required void Function(int stepIndex) onStepTick,
  });

  /// Updates the playing loop buffer seamlessly when the user toggles notes or instruments while playing.
  Future<void> updateLoopBuffer(Uint8List wavBytes, {required int bpm});

  /// Stops active 16-step loop playback and cancels the playhead timer.
  Future<void> stopLoopPlayback();

  /// Plays an instant single-note/chord hit when tapping a grid cell or live scale pad.
  Future<void> playSingleNoteHit(Uint8List wavBytes);

  /// Plays a 1.8s formant-shaped vocal preview phrase for the 24 Regional Voice Catalog.
  Future<void> playVocalPreview(Uint8List wavBytes, {VoidCallback? onComplete});

  /// Stops any active vocal preview.
  Future<void> stopVocalPreview();

  /// Releases underlying native audio players.
  Future<void> dispose();
}

/// Production hardware audio playback service backed by `just_audio` + `audio_session`,
/// with automatic headless `flutter test` guard so widget tests never throw `MissingPluginException`
/// or leak periodic timers.
class RealSketchpadAudioPlayerService implements ISketchpadAudioPlayerService {
  RealSketchpadAudioPlayerService({bool? forceHeadlessMode})
    : _isHeadless =
          forceHeadlessMode ??
          (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  final bool _isHeadless;
  AudioPlayer? _loopPlayer;
  AudioPlayer? _fxPlayer;
  Timer? _playheadTimer;
  Timer? _vocalPreviewTimer;
  bool _sessionConfigured = false;
  int _currentStep = 0;
  int _fxFileToggle = 0;

  Future<void> _ensureAudioSession() async {
    if (_isHeadless || _sessionConfigured) return;
    _sessionConfigured = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (_) {
      // Safe fallback on desktop/platforms without audio_session channel
    }
  }

  AudioPlayer _getLoopPlayer() {
    return _loopPlayer ??= AudioPlayer();
  }

  AudioPlayer _getFxPlayer() {
    return _fxPlayer ??= AudioPlayer();
  }

  Future<void> _loadWavIntoPlayer(
    AudioPlayer player,
    Uint8List wavBytes,
    String filePrefix,
  ) async {
    if (!kIsWeb) {
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$filePrefix.wav');
        await file.writeAsBytes(wavBytes, flush: true);
        await player.setFilePath(file.path);
        return;
      } catch (_) {
        // Fallback to in-memory data URI below
      }
    }
    await player.setAudioSource(
      AudioSource.uri(Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav')),
    );
  }

  @override
  Future<void> startLoopPlayback(
    Uint8List wavBytes, {
    required int bpm,
    required void Function(int stepIndex) onStepTick,
  }) async {
    _playheadTimer?.cancel();
    if (_isHeadless) return;

    await _ensureAudioSession();
    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.sketchpad,
      onPreemptPause: () async {
        await stopLoopPlayback();
        await stopVocalPreview();
      },
    );
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'sketchpad:startLoopPlayback',
      action: () async {
        final player = _getLoopPlayer();
        await player.stop();
        await _loadWavIntoPlayer(player, wavBytes, 'vhunambi_skp_loop');
        await player.setLoopMode(LoopMode.one);
        await player.setVolume(1.0);
        unawaited(player.play());

        final stepMs = (60000.0 / bpm.clamp(60, 180) / 4.0).round().clamp(
          75,
          300,
        );
        _currentStep = 0;
        _playheadTimer = Timer.periodic(Duration(milliseconds: stepMs), (_) {
          _currentStep = (_currentStep + 1) % 16;
          onStepTick(_currentStep);
        });
      },
    );
  }

  @override
  Future<void> updateLoopBuffer(Uint8List wavBytes, {required int bpm}) async {
    if (_isHeadless || _loopPlayer == null) return;
    try {
      final player = _getLoopPlayer();
      final pos = player.position;
      await _loadWavIntoPlayer(player, wavBytes, 'vhunambi_skp_loop');
      await player.setLoopMode(LoopMode.one);
      if (pos > Duration.zero) {
        await player.seek(pos);
      }
      unawaited(player.play());
    } catch (_) {}
  }

  @override
  Future<void> stopLoopPlayback() async {
    _playheadTimer?.cancel();
    _playheadTimer = null;
    if (_isHeadless || _loopPlayer == null) return;
    try {
      await _loopPlayer?.stop();
    } catch (_) {}
  }

  @override
  Future<void> playSingleNoteHit(Uint8List wavBytes) async {
    if (_isHeadless) return;
    await _ensureAudioSession();
    try {
      final player = _getFxPlayer();
      _fxFileToggle = (_fxFileToggle + 1) % 2;
      await _loadWavIntoPlayer(
        player,
        wavBytes,
        'vhunambi_skp_hit_$_fxFileToggle',
      );
      await player.setLoopMode(LoopMode.off);
      await player.setVolume(0.95);
      unawaited(player.play());
    } catch (_) {}
  }

  @override
  Future<void> playVocalPreview(
    Uint8List wavBytes, {
    VoidCallback? onComplete,
  }) async {
    _vocalPreviewTimer?.cancel();
    if (_isHeadless) return;
    await _ensureAudioSession();
    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.sketchpad,
      onPreemptPause: () async {
        await stopLoopPlayback();
        await stopVocalPreview();
      },
    );
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'sketchpad:playVocalPreview',
      action: () async {
        final player = _getFxPlayer();
        await player.stop();
        _fxFileToggle = (_fxFileToggle + 1) % 2;
        await _loadWavIntoPlayer(
          player,
          wavBytes,
          'vhunambi_vox_preview_$_fxFileToggle',
        );
        await player.setLoopMode(LoopMode.off);
        await player.setVolume(1.0);
        unawaited(player.play());

        if (onComplete != null) {
          _vocalPreviewTimer = Timer(const Duration(milliseconds: 1850), () {
            onComplete();
          });
        }
      },
    );
  }

  @override
  Future<void> stopVocalPreview() async {
    _vocalPreviewTimer?.cancel();
    _vocalPreviewTimer = null;
    if (_isHeadless || _fxPlayer == null) return;
    try {
      await _fxPlayer?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _playheadTimer?.cancel();
    _vocalPreviewTimer?.cancel();
    SafeAudioOrchestrator.instance.unregisterSlot(AudioEngineSlot.sketchpad);
    if (_isHeadless) return;
    try {
      await _loopPlayer?.dispose();
      await _fxPlayer?.dispose();
    } catch (_) {}
  }
}

/// Global Riverpod provider for the Sketchpad & Vocal Catalog hardware audio player service.
final sketchpadAudioPlayerServiceProvider =
    Provider<ISketchpadAudioPlayerService>((ref) {
      final service = RealSketchpadAudioPlayerService();
      ref.onDispose(() {
        unawaited(service.dispose());
      });
      return service;
    });
