import 'dart:async';
import '../../domain/models/stem_mixer_state.dart';
import '../../domain/services/i_multi_stem_audio_engine.dart';

/// In-memory headless multi-stem engine for deterministic testing & CI/CD (REQ-STEM-AUDIO-06).
class HeadlessMultiStemEngine implements IMultiStemAudioEngine {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  final Duration _totalDuration = const Duration(seconds: 180);

  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  final Map<StemType, double> _volumes = {
    StemType.vocals: 1.0,
    StemType.drums: 1.0,
    StemType.bass: 1.0,
    StemType.melody: 1.0,
  };

  final Map<StemType, double> _pans = {
    StemType.vocals: 0.0,
    StemType.drums: 0.0,
    StemType.bass: 0.0,
    StemType.melody: 0.0,
  };

  bool _hasRealStems;
  Duration? _measuredDrift;
  bool _isDisposed = false;

  HeadlessMultiStemEngine({
    this._hasRealStems = true,
    this._measuredDrift = Duration.zero,
  });

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get totalDuration => _totalDuration;

  @override
  bool get hasRealStems => _hasRealStems;

  @override
  Duration? get measuredDrift => _measuredDrift;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  Map<StemType, double> get channelVolumes => Map.unmodifiable(_volumes);
  Map<StemType, double> get channelPans => Map.unmodifiable(_pans);

  /// Test helper to simulate inter-channel drift.
  void setMeasuredDrift(Duration? drift) {
    _measuredDrift = drift;
  }

  /// Test helper to toggle real stems vs master-only mode.
  void setHasRealStems(bool value) {
    _hasRealStems = value;
  }

  @override
  Future<void> loadFromManifest({
    required Map<StemType, String> stemUrls,
    required String masterUrl,
  }) async {
    // Only real stems if all 4 stem types are present with non-empty URLs
    final hasAllStems = stemUrls.containsKey(StemType.vocals) &&
        stemUrls.containsKey(StemType.drums) &&
        stemUrls.containsKey(StemType.bass) &&
        stemUrls.containsKey(StemType.melody);

    _hasRealStems = hasAllStems;
    _measuredDrift = _hasRealStems ? Duration.zero : null;
    _currentPosition = Duration.zero;
    if (!_isDisposed) {
      _positionController.add(_currentPosition);
    }
  }

  @override
  Future<void> play() async {
    if (_isDisposed) return;
    _isPlaying = true;
    _isPlayingController.add(true);
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    _isPlaying = false;
    _isPlayingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    _currentPosition = position;
    _positionController.add(_currentPosition);
  }

  @override
  void applyMixerState(StemMixerState state) {
    if (_isDisposed) return;
    final anySolo = state.anySoloActive;
    for (final channel in state.channels) {
      _volumes[channel.type] = channel.effectiveVolume(anySolo);
      _pans[channel.type] = channel.pan;
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _isPlaying = false;
    await _isPlayingController.close();
    await _positionController.close();
  }
}
