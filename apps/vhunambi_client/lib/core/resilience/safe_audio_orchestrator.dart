import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';

/// Mutually exclusive hardware audio engine slots (REQ-P65-L2-01).
enum AudioEngineSlot {
  masterPlayer,
  stemMixer,
  reelPool,
  sketchpad,
}

/// Centralized single-active-engine hardware audio mutex & exception guard.
///
/// Prevents concurrent ExoPlayer/MediaCodec pool exhaustion across:
/// - [AudioEngineSlot.masterPlayer] (`VhunambiAudioHandler`)
/// - [AudioEngineSlot.stemMixer] (`JustAudioMultiStemEngine`)
/// - [AudioEngineSlot.reelPool] (`RealReelAudioPoolService`)
/// - [AudioEngineSlot.sketchpad] (`RealSketchpadAudioPlayerService`)
class SafeAudioOrchestrator {
  SafeAudioOrchestrator._();

  static final SafeAudioOrchestrator instance = SafeAudioOrchestrator._();

  final Map<AudioEngineSlot, Future<void> Function()> _preemptCallbacks =
      <AudioEngineSlot, Future<void> Function()>{};

  AudioEngineSlot? _activeSlot;
  Future<void> _mutexChain = Future<void>.value();

  AudioEngineSlot? get activeSlot => _activeSlot;

  /// Registers a pause/release callback invoked when another slot preempts [slot].
  void registerSlot(
    AudioEngineSlot slot,
    Future<void> Function() onPreemptPause,
  ) {
    _preemptCallbacks[slot] = onPreemptPause;
  }

  /// Unregisters [slot] on service disposal.
  void unregisterSlot(AudioEngineSlot slot) {
    _preemptCallbacks.remove(slot);
    if (_activeSlot == slot) {
      _activeSlot = null;
    }
  }

  /// Serializes slot acquisition and pauses any competing active engine first.
  Future<void> acquireSlot(
    AudioEngineSlot slot, {
    Future<void> Function()? onPreemptPause,
  }) {
    if (onPreemptPause != null) {
      _preemptCallbacks[slot] = onPreemptPause;
    }

    final completer = Completer<void>();
    _mutexChain = _mutexChain
        .then((_) async {
          final previous = _activeSlot;
          if (previous != null && previous != slot) {
            final pausePrevious = _preemptCallbacks[previous];
            if (pausePrevious != null) {
              await guardAudioOp<void>(
                source: 'preempt:${previous.name}->${slot.name}',
                action: pausePrevious,
              );
            }
          }
          _activeSlot = slot;
          if (!completer.isCompleted) {
            completer.complete();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          VhunambiCrashShield.recordBreadcrumb(
            source: 'safe_audio_orchestrator:acquireSlot',
            error: error,
            stackTrace: stackTrace,
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        });

    return completer.future;
  }

  /// Marks [slot] idle without triggering preemption callbacks.
  void releaseSlot(AudioEngineSlot slot) {
    if (_activeSlot == slot) {
      _activeSlot = null;
    }
  }

  /// Resets state between unit tests.
  @visibleForTesting
  void resetForTesting() {
    _preemptCallbacks.clear();
    _activeSlot = null;
    _mutexChain = Future<void>.value();
  }

  /// Wraps any `just_audio` / platform media operation in a timeout-bounded
  /// exception shield catching [PlayerException], [PlayerInterruptedException],
  /// [PlatformException], and [TimeoutException].
  static Future<T?> guardAudioOp<T>({
    required String source,
    required Future<T> Function() action,
    Duration timeout = const Duration(seconds: 6),
    T? fallbackValue,
  }) async {
    try {
      return await action().timeout(timeout);
    } on PlayerInterruptedException catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: 'audio_interrupted:$source',
        error: error,
        stackTrace: stackTrace,
      );
      return fallbackValue;
    } on PlayerException catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: 'player_exception:$source',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('[SafeAudioOrchestrator] PlayerException in $source: $error');
      return fallbackValue;
    } on PlatformException catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: 'platform_audio:$source',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('[SafeAudioOrchestrator] PlatformException in $source: $error');
      return fallbackValue;
    } on TimeoutException catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: 'audio_timeout:$source',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('[SafeAudioOrchestrator] Timeout in $source');
      return fallbackValue;
    } catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: 'audio_unknown:$source',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('[SafeAudioOrchestrator] Contained audio error in $source: $error');
      return fallbackValue;
    }
  }
}

