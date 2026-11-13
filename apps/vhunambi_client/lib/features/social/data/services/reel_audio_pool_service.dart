import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vhunambi_client/core/resilience/safe_audio_orchestrator.dart';
import '../../domain/models/published_clip.dart';
import '../../../studio/domain/services/melody_wav_synthesizer.dart';

/// Contract for the 3-Slot Recycled Reel Audio Controller Pool (REQ-SOC-26, Phase A).
///
/// Enforces the featherlight memory invariant:
/// - Maximum 3 active controller slots at any time: `Index - 1` (pre-buffered),
///   `Index` (actively playing), and `Index + 1` (pre-loaded).
/// - Any slot outside `[activeIndex - 1, activeIndex + 1]` is immediately
///   evicted and disposed to prevent Android MediaCodec exhaustion.
abstract class IReelAudioPoolService {
  /// Maximum concurrent player instances allowed in memory.
  static const int maxPoolSize = 3;

  /// Currently active reel index (`-1` when idle).
  int get activeIndex;

  /// Currently active clip ID (`null` when idle).
  String? get activeClipId;

  /// Indices currently resident in the 3-slot pool (`len <= 3`).
  Set<int> get pooledIndices;

  /// Whether the active reel slot is currently playing.
  bool get isPlaying;

  /// Current playback position in seconds for the active reel.
  double get currentPositionSec;

  /// Activates the 3-slot window around [activeIndex] for [clips], evicting
  /// any out-of-window controllers, pre-buffering adjacent slots, and starting
  /// playback on [activeIndex] when [autoPlay] is true.
  Future<void> activateWindow({
    required List<PublishedClip> clips,
    required int activeIndex,
    bool autoPlay = true,
    required void Function(double positionSec, bool isPlaying) onStateTick,
  });

  /// Toggles play/pause on the currently active slot.
  Future<bool> togglePlayPause();

  /// Explicitly pauses the active slot.
  Future<void> pause();

  /// Explicitly resumes the active slot.
  Future<void> resume();

  /// Seeks the active slot to [positionSec].
  Future<void> seek(double positionSec);

  /// Stops and evicts all pooled slots when exiting the reels feed.
  Future<void> stopAll();

  /// Permanently releases all native resources.
  Future<void> dispose();
}

class _ReelPlayerSlot {
  final int index;
  final PublishedClip clip;
  final AudioPlayer? player;
  bool isPrepared = false;
  bool isPlaying = false;
  double positionSec = 0.0;

  _ReelPlayerSlot({required this.index, required this.clip, this.player});

  Future<void> dispose() async {
    isPlaying = false;
    try {
      await player?.stop();
      await player?.dispose();
    } catch (_) {}
  }
}

/// Production 3-slot recycled `just_audio` pool with automatic WAV groove
/// synthesis fallback for seed/offline reels and headless `flutter test` safety.
class RealReelAudioPoolService implements IReelAudioPoolService {
  RealReelAudioPoolService({bool? forceHeadlessMode})
    : _isHeadless =
          forceHeadlessMode ??
          (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  final bool _isHeadless;
  final Map<int, _ReelPlayerSlot> _slots = <int, _ReelPlayerSlot>{};

  int _activeIndex = -1;
  String? _activeClipId;
  bool _isPlaying = false;
  double _currentPositionSec = 0.0;
  double _cycleDurationSec = 16.0;
  bool _sessionConfigured = false;
  bool _disposed = false;

  Timer? _positionTicker;
  void Function(double positionSec, bool isPlaying)? _onStateTick;

  @override
  int get activeIndex => _activeIndex;

  @override
  String? get activeClipId => _activeClipId;

  @override
  Set<int> get pooledIndices => Set<int>.unmodifiable(_slots.keys.toSet());

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get currentPositionSec => _currentPositionSec;

  Future<void> _ensureAudioSession() async {
    if (_isHeadless || _sessionConfigured) return;
    _sessionConfigured = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (_) {}
  }

  /// Resolves the loop cycle duration for lyric and MMO synchronization.
  static double resolveCycleDurationSec(PublishedClip clip) {
    final alignment = clip.dna.alignment;
    if (alignment.isNotEmpty) {
      final maxEnd = alignment
          .map((w) => w.end)
          .fold<double>(0.0, (prev, el) => el > prev ? el : prev);
      if (maxEnd > 4.0) {
        return (maxEnd + 1.5).clamp(8.0, 30.0);
      }
    }
    return 15.0;
  }

  /// Checks whether [audioUrl] points to a mock/seed placeholder domain that
  /// should be synthesized locally via `MelodyWavSynthesizer`.
  static bool isSeedOrPlaceholderUrl(String audioUrl) {
    final trimmed = audioUrl.trim().toLowerCase();
    if (trimmed.isEmpty) return true;
    return trimmed.contains('cdn.vhunambi.com') ||
        trimmed.contains('r2.vhunambi.com') ||
        trimmed.contains('cdn/test.mp3') ||
        trimmed.contains('example.com');
  }

  Future<void> _prepareSlot(_ReelPlayerSlot slot) async {
    if (_isHeadless || _disposed || slot.isPrepared) {
      slot.isPrepared = true;
      return;
    }

    final player = slot.player;
    if (player == null) return;

    final clip = slot.clip;
    final url = clip.audioUrl.trim();

    try {
      if (!isSeedOrPlaceholderUrl(url)) {
        if (url.startsWith('file://') ||
            (!url.startsWith('http') && File(url).existsSync())) {
          final filePath = url.startsWith('file://')
              ? Uri.parse(url).toFilePath()
              : url;
          await player.setFilePath(filePath);
          await player.setLoopMode(LoopMode.one);
          slot.isPrepared = true;
          return;
        } else if (url.startsWith('http://') || url.startsWith('https://')) {
          await player.setUrl(url).timeout(const Duration(seconds: 3));
          await player.setLoopMode(LoopMode.one);
          slot.isPrepared = true;
          return;
        }
      }
    } catch (_) {
      // Network stream unreachable or offline; fall through to local WAV synthesis
    }

    // Synthesize authentic genre-locked African groove WAV for zero-buffer playback
    try {
      final wavBytes = MelodyWavSynthesizer.synthesizeReelGrooveWavBytes(
        genre: clip.genre,
        bpm: clip.dna.musical.bpm,
        musicalKey: clip.dna.musical.key,
        seed: clip.id.hashCode,
      );
      if (!kIsWeb) {
        final safeId = clip.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        final file = File(
          '${Directory.systemTemp.path}/vhunambi_reel_$safeId.wav',
        );
        await file.writeAsBytes(wavBytes, flush: true);
        await player.setFilePath(file.path);
      } else {
        await player.setAudioSource(
          AudioSource.uri(Uri.dataFromBytes(wavBytes, mimeType: 'audio/wav')),
        );
      }
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1.0);
      slot.isPrepared = true;
    } catch (_) {}
  }

  @override
  Future<void> activateWindow({
    required List<PublishedClip> clips,
    required int activeIndex,
    bool autoPlay = true,
    required void Function(double positionSec, bool isPlaying) onStateTick,
  }) async {
    if (_disposed || clips.isEmpty) return;

    final clampedIndex = activeIndex.clamp(0, clips.length - 1);
    _onStateTick = onStateTick;
    _activeIndex = clampedIndex;
    final activeClip = clips[clampedIndex];
    _activeClipId = activeClip.id;
    _cycleDurationSec = resolveCycleDurationSec(activeClip);
    _currentPositionSec = 0.0;
    _isPlaying = autoPlay;

    // Compute 3-slot window: {Index - 1, Index, Index + 1}
    final allowedIndices = <int>{
      if (clampedIndex > 0) clampedIndex - 1,
      clampedIndex,
      if (clampedIndex + 1 < clips.length) clampedIndex + 1,
    };

    // 1. Evict & dispose any slot outside the 3-slot window
    final toEvict = _slots.keys
        .where((idx) => !allowedIndices.contains(idx))
        .toList(growable: false);
    for (final idx in toEvict) {
      final evicted = _slots.remove(idx);
      if (evicted != null) {
        unawaited(evicted.dispose());
      }
    }

    // 2. Allocate missing slots in the 3-slot window
    for (final idx in allowedIndices) {
      _slots.putIfAbsent(
        idx,
        () => _ReelPlayerSlot(
          index: idx,
          clip: clips[idx],
          player: _isHeadless ? null : AudioPlayer(),
        ),
      );
    }

    // 3. Pause adjacent slots and reset their position
    for (final entry in _slots.entries) {
      if (entry.key != clampedIndex) {
        entry.value.isPlaying = false;
        entry.value.positionSec = 0.0;
        if (!_isHeadless) {
          try {
            unawaited(entry.value.player?.pause());
            unawaited(entry.value.player?.seek(Duration.zero));
          } catch (_) {}
        }
      }
    }

    final currentSlot = _slots[clampedIndex]!;
    currentSlot.positionSec = 0.0;
    currentSlot.isPlaying = autoPlay;

    if (_isHeadless) {
      for (final slot in _slots.values) {
        slot.isPrepared = true;
      }
      _onStateTick?.call(_currentPositionSec, _isPlaying);
      return;
    }

    await _ensureAudioSession();
    SafeAudioOrchestrator.instance.registerSlot(
      AudioEngineSlot.reelPool,
      () => pause(),
    );
    if (autoPlay) {
      await SafeAudioOrchestrator.instance.acquireSlot(
        AudioEngineSlot.reelPool,
        onPreemptPause: () => pause(),
      );
    }

    // Prepare and play the active slot immediately
    await _prepareSlot(currentSlot);
    if (_disposed || _activeIndex != clampedIndex) return;

    if (autoPlay) {
      await SafeAudioOrchestrator.guardAudioOp<void>(
        source: 'reel_pool:activateWindow_play',
        action: () async {
          await currentSlot.player?.seek(Duration.zero);
          await currentSlot.player?.play();
        },
      );
      _startPositionTicker();
    } else {
      _positionTicker?.cancel();
    }

    // Pre-buffer adjacent slots (Index - 1 and Index + 1) in background
    for (final idx in allowedIndices) {
      if (idx != clampedIndex && _slots.containsKey(idx)) {
        unawaited(_prepareSlot(_slots[idx]!));
      }
    }
  }

  void _startPositionTicker() {
    _positionTicker?.cancel();
    if (_isHeadless || _disposed) return;

    _positionTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isPlaying || _disposed) return;
      _currentPositionSec = (_currentPositionSec + 0.05) % _cycleDurationSec;
      final slot = _slots[_activeIndex];
      if (slot != null) {
        slot.positionSec = _currentPositionSec;
      }
      _onStateTick?.call(_currentPositionSec, _isPlaying);
    });
  }

  @override
  Future<bool> togglePlayPause() async {
    if (_disposed || _activeIndex < 0) return false;
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
    return _isPlaying;
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _isPlaying = false;
    _positionTicker?.cancel();
    final slot = _slots[_activeIndex];
    if (slot != null) {
      slot.isPlaying = false;
      if (!_isHeadless) {
        await SafeAudioOrchestrator.guardAudioOp<void>(
          source: 'reel_pool:pause',
          action: () async => slot.player?.pause(),
        );
      }
    }
    _onStateTick?.call(_currentPositionSec, _isPlaying);
  }

  @override
  Future<void> resume() async {
    if (_disposed || _activeIndex < 0) return;
    _isPlaying = true;
    final slot = _slots[_activeIndex];
    if (slot != null) {
      slot.isPlaying = true;
      if (!_isHeadless) {
        await SafeAudioOrchestrator.instance.acquireSlot(
          AudioEngineSlot.reelPool,
          onPreemptPause: () => pause(),
        );
        await SafeAudioOrchestrator.guardAudioOp<void>(
          source: 'reel_pool:resume',
          action: () async {
            if (!slot.isPrepared) {
              await _prepareSlot(slot);
            }
            await slot.player?.play();
          },
        );
        _startPositionTicker();
      }
    }
    _onStateTick?.call(_currentPositionSec, _isPlaying);
  }

  @override
  Future<void> seek(double positionSec) async {
    if (_disposed) return;
    final clamped = positionSec.clamp(0.0, _cycleDurationSec);
    _currentPositionSec = clamped;
    final slot = _slots[_activeIndex];
    if (slot != null) {
      slot.positionSec = clamped;
      if (!_isHeadless) {
        try {
          final ms = (clamped * 1000).round();
          await slot.player?.seek(Duration(milliseconds: ms));
        } catch (_) {}
      }
    }
    _onStateTick?.call(_currentPositionSec, _isPlaying);
  }

  @override
  Future<void> stopAll() async {
    _positionTicker?.cancel();
    _positionTicker = null;
    _isPlaying = false;
    _currentPositionSec = 0.0;
    _activeIndex = -1;
    _activeClipId = null;

    final slotsToDispose = _slots.values.toList(growable: false);
    _slots.clear();
    for (final slot in slotsToDispose) {
      await slot.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    SafeAudioOrchestrator.instance.unregisterSlot(AudioEngineSlot.reelPool);
    await stopAll();
  }
}
