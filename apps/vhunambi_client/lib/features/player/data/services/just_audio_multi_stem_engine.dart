import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/models/stem_mixer_state.dart';
import '../../domain/services/i_multi_stem_audio_engine.dart';
import 'audio_session_manager.dart';

/// Production multi-channel synchronized stem audio playback engine (REQ-STEM-AUDIO-01 .. 06).
///
/// Manages 4 [AudioPlayer] instances for isolated stems (vocals, drums, bass, melody)
/// or gracefully falls back to a single master player when real stems are absent.
/// Measures inter-channel drift every 500 ms and resyncs if drift exceeds 40 ms.
class JustAudioMultiStemEngine implements IMultiStemAudioEngine {
  final IAudioSessionManager? sessionManager;

  // 4 stem players
  final AudioPlayer _vocalsPlayer;
  final AudioPlayer _drumsPlayer;
  final AudioPlayer _bassPlayer;
  final AudioPlayer _melodyPlayer;

  // Master fallback player
  final AudioPlayer _masterPlayer;

  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<dynamic>? _interruptionSub;
  Timer? _driftTimer;

  bool _hasRealStems = false;
  Duration? _measuredDrift;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isDisposed = false;

  JustAudioMultiStemEngine({
    this.sessionManager,
    AudioPlayer? vocalsPlayer,
    AudioPlayer? drumsPlayer,
    AudioPlayer? bassPlayer,
    AudioPlayer? melodyPlayer,
    AudioPlayer? masterPlayer,
  })  : _vocalsPlayer = vocalsPlayer ?? AudioPlayer(),
        _drumsPlayer = drumsPlayer ?? AudioPlayer(),
        _bassPlayer = bassPlayer ?? AudioPlayer(),
        _melodyPlayer = melodyPlayer ?? AudioPlayer(),
        _masterPlayer = masterPlayer ?? AudioPlayer() {
    _setupAudioSession();
  }

  void _setupAudioSession() {
    final session = sessionManager;
    if (session == null) return;
    _interruptionSub = session.interruptionStream.listen((event) {
      if (event.isInterrupted && _isPlaying) {
        pause();
      }
    });
  }

  @override
  bool get hasRealStems => _hasRealStems;

  @override
  Duration? get measuredDrift => _measuredDrift;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get totalDuration => _totalDuration;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> loadFromManifest({
    required Map<StemType, String> stemUrls,
    required String masterUrl,
  }) async {
    if (_isDisposed) return;

    await pause();
    await _posSub?.cancel();
    _currentPosition = Duration.zero;

    final hasAllStems = stemUrls.containsKey(StemType.vocals) &&
        stemUrls.containsKey(StemType.drums) &&
        stemUrls.containsKey(StemType.bass) &&
        stemUrls.containsKey(StemType.melody) &&
        (stemUrls[StemType.vocals]?.isNotEmpty ?? false) &&
        (stemUrls[StemType.drums]?.isNotEmpty ?? false) &&
        (stemUrls[StemType.bass]?.isNotEmpty ?? false) &&
        (stemUrls[StemType.melody]?.isNotEmpty ?? false);

    if (hasAllStems) {
      _hasRealStems = true;
      _measuredDrift = Duration.zero;

      try {
        final durations = await Future.wait([
          _vocalsPlayer.setUrl(stemUrls[StemType.vocals]!),
          _drumsPlayer.setUrl(stemUrls[StemType.drums]!),
          _bassPlayer.setUrl(stemUrls[StemType.bass]!),
          _melodyPlayer.setUrl(stemUrls[StemType.melody]!),
        ]);

        // Derive total duration from reference stem
        _totalDuration = durations.whereType<Duration>().isNotEmpty
            ? durations.whereType<Duration>().reduce((a, b) => a > b ? a : b)
            : const Duration(seconds: 180);

        _posSub = _drumsPlayer.positionStream.listen((pos) {
          _currentPosition = pos;
          if (!_isDisposed) _positionController.add(pos);
        });
      } catch (e) {
        debugPrint(
            'JustAudioMultiStemEngine: error loading stems, falling back to master: $e');
        _hasRealStems = false;
        _measuredDrift = null;
        await _loadMasterOnly(masterUrl);
      }
    } else {
      _hasRealStems = false;
      _measuredDrift = null;
      await _loadMasterOnly(masterUrl);
    }
  }

  Future<void> _loadMasterOnly(String masterUrl) async {
    if (masterUrl.isEmpty) return;
    try {
      final dur = await _masterPlayer.setUrl(masterUrl);
      _totalDuration = dur ?? const Duration(seconds: 180);
      _posSub = _masterPlayer.positionStream.listen((pos) {
        _currentPosition = pos;
        if (!_isDisposed) _positionController.add(pos);
      });
    } catch (e) {
      debugPrint('JustAudioMultiStemEngine: error loading master audio: $e');
    }
  }

  @override
  Future<void> play() async {
    if (_isDisposed || _isPlaying) return;

    if (_hasRealStems) {
      await Future.wait([
        _vocalsPlayer.play(),
        _drumsPlayer.play(),
        _bassPlayer.play(),
        _melodyPlayer.play(),
      ]);
      _startDriftMonitoring();
    } else {
      await _masterPlayer.play();
    }

    _isPlaying = true;
    if (!_isDisposed) _isPlayingController.add(true);
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    _stopDriftMonitoring();

    if (_hasRealStems) {
      await Future.wait([
        _vocalsPlayer.pause(),
        _drumsPlayer.pause(),
        _bassPlayer.pause(),
        _melodyPlayer.pause(),
      ]);
    } else {
      await _masterPlayer.pause();
    }

    _isPlaying = false;
    if (!_isDisposed) _isPlayingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;

    if (_hasRealStems) {
      await Future.wait([
        _vocalsPlayer.seek(position),
        _drumsPlayer.seek(position),
        _bassPlayer.seek(position),
        _melodyPlayer.seek(position),
      ]);
    } else {
      await _masterPlayer.seek(position);
    }

    _currentPosition = position;
    if (!_isDisposed) _positionController.add(position);
  }

  @override
  void applyMixerState(StemMixerState state) {
    if (_isDisposed || !_hasRealStems) return;

    final anySolo = state.anySoloActive;
    for (final channel in state.channels) {
      final vol = channel.effectiveVolume(anySolo);
      switch (channel.type) {
        case StemType.vocals:
          _vocalsPlayer.setVolume(vol);
          break;
        case StemType.drums:
          _drumsPlayer.setVolume(vol);
          break;
        case StemType.bass:
          _bassPlayer.setVolume(vol);
          break;
        case StemType.melody:
          _melodyPlayer.setVolume(vol);
          break;
      }
      // Live stereo pan is omitted as just_audio does not support per-player pan.
      // Panning is applied during offline mixdown bounce.
    }
  }

  void _startDriftMonitoring() {
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkAndCorrectDrift();
    });
  }

  void _stopDriftMonitoring() {
    _driftTimer?.cancel();
    _driftTimer = null;
  }

  void _checkAndCorrectDrift() {
    if (!_hasRealStems || !_isPlaying || _isDisposed) return;

    final ref = _drumsPlayer.position;
    final vocalsDiff = (_vocalsPlayer.position - ref).inMilliseconds.abs();
    final bassDiff = (_bassPlayer.position - ref).inMilliseconds.abs();
    final melodyDiff = (_melodyPlayer.position - ref).inMilliseconds.abs();

    final maxDiffMs = math.max(vocalsDiff, math.max(bassDiff, melodyDiff));
    _measuredDrift = Duration(milliseconds: maxDiffMs);

    // If drift exceeds sync target (40 ms), resync drifting players
    if (maxDiffMs > 40) {
      if (vocalsDiff > 40) _vocalsPlayer.seek(ref);
      if (bassDiff > 40) _bassPlayer.seek(ref);
      if (melodyDiff > 40) _melodyPlayer.seek(ref);
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _stopDriftMonitoring();
    await _posSub?.cancel();
    await _interruptionSub?.cancel();

    await Future.wait([
      _vocalsPlayer.dispose(),
      _drumsPlayer.dispose(),
      _bassPlayer.dispose(),
      _melodyPlayer.dispose(),
      _masterPlayer.dispose(),
    ]);

    await _isPlayingController.close();
    await _positionController.close();
  }
}
