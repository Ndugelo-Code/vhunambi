# Phase 65 — Detailed Engineering Design (`VHUNAMBI-SPEC-P65-DESIGN-V1`)

**Document ID**: `VHUNAMBI-SPEC-P65-DESIGN-V1`  
**Phase**: `Phase 65`  
**Companion Blueprint**: [`blueprint.md`](./blueprint.md)  
**Companion Requirements**: [`requirements.md`](./requirements.md)  
**Companion Tasks**: [`tasks.md`](./tasks.md)

---

## 1. Mathematical & Algorithmic Foundations

### 1.1 Single-Active-Engine Audio Mutex & Serialized Operation Queue (`SafeAudioOrchestrator`)
Let $\mathcal{S} = \{\text{masterPlayer}, \text{stemMixer}, \text{reelPool}, \text{sketchpad}\}$ be the four hardware audio slots. Each slot $s \in \mathcal{S}$ registers a preemption pause callback $\pi_s : () \to \text{Future}\langle\text{void}\rangle$. All slot acquisitions and hardware mutations execute through a strictly serialized FIFO promise chain $\mathcal{C}_k$:

$$
\mathcal{C}_k = \mathcal{C}_{k-1}.\text{then}\left(\text{async } () \implies \begin{cases}
\text{await } \text{guardAudioOp}(\pi_{s_{\text{prev}}}) & \text{if } s_{\text{prev}} \neq \varnothing \land s_{\text{prev}} \neq s_{\text{next}} \\
s_{\text{active}} \leftarrow s_{\text{next}} \\
\text{return await } \text{guardAudioOp}(\text{action})
\end{cases}\right)
$$

Every hardware operation $\text{op}$ is bounded by a timeout $\tau = 6\text{ s}$ and traps `PlayerException`, `PlayerInterruptedException`, `PlatformException`, and `TimeoutException` into `VhunambiCrashShield.recordBreadcrumb(...)`.

### 1.2 IEEE 802.3 CRC32 & RFC-2083 Binary PNG Construction (`synthesizeCoverPngBytes`)
To generate a genuine binary PNG (`\x89PNG\r\n\x1a\n`) without external native image libraries on Cloudflare Workers or Node.js:
1. **Scanline Filter Framing**: For a $W \times H$ RGB888 image ($W = 64, H = 64$), each row $y \in [0, H-1]$ is prefixed with filter byte `0x00` (None), yielding raw scanline buffer $S$ of length $H(1 + 3W) = 12,352$ bytes.
2. **Zlib Deflate Compression**: $Z = \text{deflateSync}(S, \{\text{level}: 6\})$ produces an RFC-1950 zlib stream with 2-byte header and 4-byte big-endian Adler-32 checksum.
3. **Chunk Framing & CRC32**: Each PNG chunk $(L, T, D, C)$ writes 4-byte big-endian length $L = |D|$, 4-byte ASCII type $T \in \{\text{"IHDR"}, \text{"IDAT"}, \text{"IEND"}\}$, payload $D$, and 4-byte big-endian CRC32 $C$:

$$
\text{CRC32}(T \Vert D) = \left(\bigoplus_{i=0}^{|T|+|D|-1} \text{step}(\text{crc}_i, b_i)\right) \oplus \text{0xFFFFFFFF}, \quad P_{\text{rev}} = \text{0xEDB88320}
$$

---

## 2. Milestone `M65.1` — Native Android Notification Vector & Layer 1 `VhunambiCrashShield`

### 2.1 New File: `apps/vhunambi_client/android/app/src/main/res/drawable/ic_stat_music.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="#FFFFFF">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z" />
</vector>
```

### 2.2 Surgical Update: `apps/vhunambi_client/android/app/src/main/AndroidManifest.xml`
Add default notification icon metadata inside `<application>` right above `<service android:name="com.ryanheise.audioservice.AudioService" ...>`:

```xml
        <!-- Phase 65 (REQ-P65-L1-01): Default monochrome small notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_stat_music" />
```

### 2.3 New File: `apps/vhunambi_client/lib/core/resilience/vhunambi_crash_shield.dart`

```dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Immutable diagnostic record captured by [VhunambiCrashShield] (REQ-P65-L1-02..04).
@immutable
class CrashBreadcrumb {
  final String source;
  final String message;
  final String? stackPreview;
  final DateTime timestamp;
  final bool isFatal;

  const CrashBreadcrumb({
    required this.source,
    required this.message,
    this.stackPreview,
    required this.timestamp,
    this.isFatal = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'message': message,
        if (stackPreview != null) 'stackPreview': stackPreview,
        'timestamp': timestamp.toIso8601String(),
        'isFatal': isFatal,
      };
}

/// Bounded ring buffer holding the most recent 100 fault breadcrumbs in memory.
class CrashBreadcrumbBuffer {
  static const int maxEntries = 100;
  final ListQueue<CrashBreadcrumb> _queue = ListQueue<CrashBreadcrumb>();

  List<CrashBreadcrumb> get entries => List<CrashBreadcrumb>.unmodifiable(_queue);

  int get length => _queue.length;

  void record({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool isFatal = false,
  }) {
    if (_queue.length >= maxEntries) {
      _queue.removeFirst();
    }
    final rawStack = stackTrace?.toString() ?? '';
    final preview = rawStack.isEmpty
        ? null
        : rawStack.split('\n').take(6).join('\n');
    _queue.addLast(
      CrashBreadcrumb(
        source: source,
        message: error.toString(),
        stackPreview: preview,
        timestamp: DateTime.now().toUtc(),
        isFatal: isFatal,
      ),
    );
  }

  void clear() => _queue.clear();
}

/// Riverpod [ProviderObserver] recording provider initialization/mutation errors
/// into [VhunambiCrashShield.breadcrumbs] without crashing the UI isolate.
class VhunambiProviderObserver extends ProviderObserver {
  const VhunambiProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    VhunambiCrashShield.recordBreadcrumb(
      source: 'provider:${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Layer 1 Root Isolate, Platform Dispatcher, Widget Build & Startup Crash Shield.
abstract final class VhunambiCrashShield {
  static final CrashBreadcrumbBuffer breadcrumbs = CrashBreadcrumbBuffer();
  static bool _installed = false;

  static bool get isInstalled => _installed;

  /// Installs Flutter, PlatformDispatcher, and ErrorWidget boundaries, then
  /// executes [appRunner] inside [runZonedGuarded].
  static void run(Future<void> Function() appRunner) {
    runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        installFrameworkHandlers();
        await appRunner();
      },
      recordZoneError,
    );
  }

  /// Installs framework error handlers idempotently (safe to call in tests).
  static void installFrameworkHandlers() {
    _installed = true;

    FlutterError.onError = recordFlutterError;

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      return recordPlatformError(error, stack);
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      recordBreadcrumb(
        source: 'error_widget_builder',
        error: details.exception,
        stackTrace: details.stack,
      );
      return VhunambiSafeErrorCard(details: details);
    };
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    breadcrumbs.record(
      source: 'flutter_error:${details.library ?? 'framework'}',
      error: details.exception,
      stackTrace: details.stack,
    );
    debugPrint(
      '[VhunambiCrashShield] FlutterError caught (${details.library}): ${details.exception}',
    );
  }

  static bool recordPlatformError(Object error, StackTrace stackTrace) {
    breadcrumbs.record(
      source: 'platform_dispatcher',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[VhunambiCrashShield] PlatformDispatcher error contained: $error');
    // Return true so uncaught async plugin/network errors never terminate the OS process.
    return true;
  }

  static void recordZoneError(Object error, StackTrace stackTrace) {
    breadcrumbs.record(
      source: 'zone_error',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[VhunambiCrashShield] Uncaught zone error contained: $error');
  }

  static void recordBreadcrumb({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool isFatal = false,
  }) {
    breadcrumbs.record(
      source: source,
      error: error,
      stackTrace: stackTrace,
      isFatal: isFatal,
    );
  }

  /// Executes a pre-`runApp` startup task with a strict timeout and fallback
  /// so a hung/corrupt disk box or missing native plugin never blocks launch.
  static Future<T> guardStartup<T>({
    required String stepName,
    required Future<T> Function() action,
    required T Function() fallback,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      return await action().timeout(timeout);
    } catch (error, stackTrace) {
      recordBreadcrumb(
        source: 'startup:$stepName',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint(
        '[VhunambiCrashShield] Startup step "$stepName" degraded cleanly: $error',
      );
      return fallback();
    }
  }
}

/// Non-crashing recovery card rendered whenever a widget subtree fails to build.
class VhunambiSafeErrorCard extends StatelessWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;

  const VhunambiSafeErrorCard({
    super.key = const Key('vhunambi_safe_error_card'),
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.shieldCheck,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Component Recovery Active',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This view recovered from a display error. Your session is safe.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  key: const Key('vhunambi_safe_error_retry_btn'),
                  onPressed: onRetry,
                  child: Text(
                    'Retry',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2.4 Surgical Update: `apps/vhunambi_client/lib/main.dart`
1. Import `core/resilience/vhunambi_crash_shield.dart`.
2. Wrap `main()` in `VhunambiCrashShield.run(...)` with bounded `guardStartup` calls and `observers: const [VhunambiProviderObserver()]`.
3. In `_RootShellState`, synchronize `_switchTab(int index)`, `_handleSystemBack()`, and `_handleSearchShortcut()` with `appNavigationTabProvider` so `MiniPlayerHost` (`tab == 2`) always receives the live tab index:

```dart
// In main.dart imports:
import 'core/resilience/vhunambi_crash_shield.dart';

Future<void> main() async {
  VhunambiCrashShield.run(() async {
    await VhunambiCrashShield.guardStartup<void>(
      stepName: 'sovereign_hive_bootstrap',
      action: () => SovereignHiveBootstrapService.ensureInitialized(),
      fallback: () {},
    );

    final prefs = await VhunambiCrashShield.guardStartup<SharedPreferences?>(
      stepName: 'shared_preferences',
      action: () => SharedPreferences.getInstance(),
      fallback: () => null,
    );

    TokenRegistration.registerAllTokens();
    DesignTokenRegistry.seal();

    final audioHandler =
        await VhunambiCrashShield.guardStartup<IVhunambiAudioHandler>(
          stepName: 'platform_audio_handler',
          action: () => bootstrapPlatformAudioHandler(),
          fallback: () => TestVhunambiAudioHandler(),
        );

    runApp(
      ProviderScope(
        observers: const [VhunambiProviderObserver()],
        overrides: [
          audioHandlerProvider.overrideWithValue(audioHandler),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const VhunambiApp(),
      ),
    );
  });
}
```

And in `_RootShellState` (`apps/vhunambi_client/lib/main.dart` lines 146–181 & 226–228):

```dart
  void _switchTab(int index) {
    if (index == _currentIndex) {
      if (ref.read(appNavigationTabProvider) != index) {
        ref.read(appNavigationTabProvider.notifier).state = index;
      }
      return;
    }
    HapticsService().selectionClick();
    if (index == 1) {
      resetExploreTitleFade(ref);
    }
    final playerController = ref.read(miniPlayerControllerProvider);
    if (playerController.form == PlayerForm.pill &&
        playerController.mode == PlayerMode.auto) {
      ref.read(miniPlayerControllerProvider.notifier).setForm(PlayerForm.bar);
    }
    setState(() {
      _tabHistory.add(index);
      _currentIndex = index;
    });
    if (ref.read(appNavigationTabProvider) != index) {
      ref.read(appNavigationTabProvider.notifier).state = index;
    }
  }

  void _handleSystemBack() {
    if (_tabHistory.length <= 1) return;
    setState(() {
      _tabHistory.removeLast();
      _currentIndex = _tabHistory.last;
    });
    if (ref.read(appNavigationTabProvider) != _currentIndex) {
      ref.read(appNavigationTabProvider.notifier).state = _currentIndex;
    }
  }

  void _handleSearchShortcut() {
    _switchTab(1);
  }
```

---

## 3. Milestone `M65.2` — Layer 2 `SafeAudioOrchestrator` & Duration/Ticker State Machine

### 3.1 New File: `apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart`

```dart
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
    _mutexChain = _mutexChain.then((_) async {
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
    }).catchError((Object error, StackTrace stackTrace) {
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
```

### 3.2 Surgical Updates for Milestone `M65.2`

#### 3.2.1 `apps/vhunambi_client/lib/core/constants/app_constants.dart`
Include `vhunambi.com` in `normalizeCloudMediaUrl` (lines 104–113) so legacy `https://vhunambi.com/audio/...` URLs rewrite cleanly to the active `/r2` media origin:

```dart
    final legacyRegex = RegExp(
      r'^https?:\/\/(?:(?:r2|cdn|assets)\.)?vhunambi\.(?:com|za)\/(.+)$',
      caseSensitive: false,
    );
    final match = legacyRegex.firstMatch(trimmed);
    if (match != null) {
      return '$mediaBase/${match.group(1)}';
    }
```

#### 3.2.2 `apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart`
1. Register `AudioEngineSlot.masterPlayer` with `SafeAudioOrchestrator.instance` in constructor and acquire slot in `playTrack` and `play()`.
2. Subscribe to `player.durationStream` (with `onError:`) in `_wirePlayerStreams()` so decoded WAV/MP3 durations update `mediaItem.add(current.copyWith(duration: duration))` immediately.
3. Add `onError:` callbacks to `player.currentIndexStream.listen`, `sessionManager.interruptionStream.listen`, and `sessionManager.becomingNoisyStream.listen`:

```dart
  void _wirePlayerStreams() {
    SafeAudioOrchestrator.instance.registerSlot(
      AudioEngineSlot.masterPlayer,
      () => pause(),
    );

    _subscriptions.add(
      player.playbackEventStream.listen(
        _broadcastPlaybackEvent,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler player error: $error');
          playbackState.add(
            buildOsPlaybackState(
              status: PlaybackStatus.error,
              position: player.position,
              speed: player.speed,
              errorMessage: error.toString(),
            ),
          );
        },
      ),
    );

    _subscriptions.add(
      player.durationStream.listen(
        (Duration? decodedDuration) {
          if (decodedDuration == null || decodedDuration <= Duration.zero) {
            return;
          }
          final currentItem = mediaItem.valueOrNull;
          if (currentItem != null && currentItem.duration != decodedDuration) {
            mediaItem.add(currentItem.copyWith(duration: decodedDuration));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler durationStream error: $error');
        },
      ),
    );

    _subscriptions.add(
      player.currentIndexStream.listen(
        (index) {
          if (index != null) _index = index;
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('VhunambiAudioHandler currentIndexStream error: $error');
        },
      ),
    );
  }
```

And in `playTrack` / `play` / `pause` / `stop` (`vhunambi_audio_handler.dart`):
```dart
    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.masterPlayer,
      onPreemptPause: () => pause(),
    );
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:setAudioSource',
      action: () => player.setAudioSource(
        audioSource,
        initialIndex: _index,
        initialPosition: Duration.zero,
      ),
    );
    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'vhunambi_audio_handler:play',
      action: () => player.play(),
    );
```

#### 3.2.3 `apps/vhunambi_client/lib/features/player/data/services/just_audio_multi_stem_engine.dart`
Wire `SafeAudioOrchestrator.instance` (`AudioEngineSlot.stemMixer`), attach `onError:` to `_interruptionSub` and `_posSub`, and wrap `play()`, `pause()`, `seek()`, and `applyMixerState()` in `SafeAudioOrchestrator.guardAudioOp`:

```dart
  void _setupAudioSession() {
    SafeAudioOrchestrator.instance.registerSlot(
      AudioEngineSlot.stemMixer,
      () => pause(),
    );
    final session = sessionManager;
    if (session == null) return;
    _interruptionSub = session.interruptionStream.listen(
      (event) {
        if (event.isInterrupted && _isPlaying) {
          unawaited(pause());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('JustAudioMultiStemEngine interruptionStream error: $error');
      },
    );
  }

  @override
  Future<void> play() async {
    if (_isDisposed || _isPlaying) return;

    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.stemMixer,
      onPreemptPause: () => pause(),
    );

    await SafeAudioOrchestrator.guardAudioOp<void>(
      source: 'multi_stem:play',
      action: () async {
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
      },
    );

    _isPlaying = true;
    if (!_isDisposed) _isPlayingController.add(true);
  }
```

#### 3.2.4 `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
In `_onGenerationComplete` (lines 467–488), remove the eager `unawaited(engine.loadFromManifest(...))` call so completing a song only starts the single master player without spinning up 5 competing stem `AudioPlayer` instances:

```dart
    // Phase 65 (REQ-P65-L2-02): Do NOT eagerly call multiStemAudioEngineProvider.loadFromManifest
    // during _onGenerationComplete. Stem players are lazy-loaded only when the user opens
    // the Stem Mixer deck, preventing 5-decoder contention with VhunambiAudioHandler.
```

#### 3.2.5 `apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart`
1. Seed `track_default_1` (`"Grateful in the Light"`) in `PlaybackStatus.paused` at `position: Duration.zero` with `audioUrl: 'https://r2.vhunambi.com/explore/track_default_1.wav'` and `duration: const Duration(seconds: 24)`.
2. Attach `onError:` to `_playbackStateSubscription` and `_mediaItemSubscription`.
3. In `_onHardwarePlaybackState`, cancel `_positionTimer` immediately whenever `mappedStatus != PlaybackStatus.playing`:

```dart
       super(
         const PlayerState(
           currentTrack: Track(
             id: 'track_default_1',
             title: 'Grateful in the Light',
             creatorName: 'Sigwa & Inaf',
             genre: 'Amapiano',
             language: 'English',
             audioUrl: 'https://r2.vhunambi.com/explore/track_default_1.wav',
             duration: Duration(seconds: 24),
             likeCount: 1002,
             playCount: 1200,
             isNew: true,
           ),
           playbackStatus: PlaybackStatus.paused,
           position: Duration.zero,
           duration: Duration(seconds: 24),
         ),
       ) {
    _hydratePersistedSession();
    _initHardwareSubscriptions();
    if (state.isPlaying) {
      _startPositionTicker();
    }
  }
```

And in `_initHardwareSubscriptions()` & `_onHardwarePlaybackState()` (`player_provider.dart` lines 179–225):
```dart
  void _initHardwareSubscriptions() {
    _playbackStateSubscription = _audioHandler.playbackState.listen(
      _onHardwarePlaybackState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('PlayerNotifier playbackState stream error: $error');
      },
    );
    _mediaItemSubscription = _audioHandler.mediaItem.listen(
      _onHardwareMediaItem,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('PlayerNotifier mediaItem stream error: $error');
      },
    );
  }
```
```dart
    if (mappedStatus == PlaybackStatus.playing) {
      if (_positionTimer == null || !_positionTimer!.isActive) {
        _startPositionTicker();
      }
    } else {
      _positionTimer?.cancel();
      _positionTimer = null;
    }
```


---

## 4. Milestone `M65.3` — Layer 3 `SafeNotifierMixin`, 14 Async Notifiers & `SafeNetworkAvatar`

### 4.1 New File: `apps/vhunambi_client/lib/core/resilience/safe_notifier_mixin.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';

/// Lifecycle-safe mixin for [StateNotifier] subclasses (REQ-P65-L3-03).
///
/// Guarantees that asynchronous callbacks resuming after `await` never throw
/// `Bad state: Tried to use <Notifier> after dispose was called`.
mixin SafeNotifierMixin<T> on StateNotifier<T> {
  /// Updates [state] only if this [StateNotifier] is still mounted.
  bool setStateIfMounted(T nextState) {
    if (!mounted) return false;
    state = nextState;
    return true;
  }

  /// Executes [action] inside a guarded async boundary and records any uncaught
  /// exception to [VhunambiCrashShield] instead of crashing the isolate.
  Future<R?> runGuarded<R>({
    required String source,
    required Future<R> Function() action,
    R? fallback,
  }) async {
    if (!mounted) return fallback;
    try {
      return await action();
    } catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: source,
        error: error,
        stackTrace: stackTrace,
      );
      return fallback;
    }
  }
}
```

### 4.2 Exact Surgical `mounted` Guards Across All 14 Async `StateNotifier` Files

1. **`apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`**:
   - Add `with SafeNotifierMixin<GenerationProgressState?>` to `GenerationPipelineNotifier`.
   - In `submitAndStartGeneration` (after `await _submissionService.submitGeneration(...)` and `await _ref.read(libraryTracksProvider.notifier)...`), check `if (!mounted) return;` before mutating `state = ...`.
2. **`apps/vhunambi_client/lib/features/studio/presentation/providers/lyrics_review_provider.dart` (line 75)**:
   ```dart
      final draft = await _service.generateLyrics(
        prompt: prompt,
        genre: genre,
        language: language,
      );
      if (!mounted) return;
      generationCount++;
      hasEdits = false;
      state = draft;
   ```
3. **`apps/vhunambi_client/lib/core/design_system/models/generation_request_notifier.dart` (lines 160–172)**:
   ```dart
  Future<void> _validateAndUpdate(GenerationRequestModel newModel) async {
    try {
      newModel.validate();
      if (!mounted) return;
      state = GenerationRequestState(model: newModel, isValid: true);
      await _persistState();
    } on GenerationRequestValidationException catch (e) {
      if (!mounted) return;
      state = GenerationRequestState(
        model: newModel,
        isValid: false,
        validationError: e.message,
      );
    }
  }
   ```
4. **`apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart` (lines 75–81)**:
   ```dart
  Future<void> recordCertificate(SovereignLicenseCertificate cert) async {
    await _repo.save(cert);
    if (!mounted) return;
    state = [
      cert,
      ...state.where((c) => c.certificateId != cert.certificateId),
    ];
  }
   ```
5. **`apps/vhunambi_client/lib/features/profile/presentation/providers/profile_operation_notifier.dart` (lines 41–49, 86–108, 123–139, 159–173, 187–201, 215–229, 243–257)**:
   - Guard `_setLoading` and `_setError` with `if (!mounted) return;` and check `if (!mounted) return;` after every `await _cache.get(artistId)` and `await operation()`.
6. **`apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart` (lines 73–79)**:
   ```dart
      final remote = await _repo.getComments(clipId);
      if (!mounted) return;
      if (remote.isNotEmpty) {
        state = state.copyWith(
          commentsByClipId: {...state.commentsByClipId, clipId: remote},
        );
        _persistCommentsForClip(clipId, remote);
      }
   ```
7. **`apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart` (lines 135–145 & 209–231)**:
   ```dart
      final remoteClips = await _repo.getFeed(limit: 20);
      if (!mounted) return;
   ```
   and in `loadMore()`:
   ```dart
        final nextClips = await _repo.getFeed(
          cursor: state.clips.length.toString(),
          limit: 10,
        );
        if (!mounted) return;
   ```
   and after `await Future<void>.delayed(...)`:
   ```dart
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    state = state.copyWith(isLoading: false, hasReachedEnd: true);
   ```
8. **`apps/vhunambi_client/lib/features/offline/presentation/providers/offline_providers.dart` (lines 270, 291, 340, 364, 394, 415)**:
   - Add `if (!mounted) return;` inside `onProgress` callback and after `await _downloadService.downloadFile(...)`, `await _downloadService.cancelDownload(...)`, `await _storageService.removeTrackMetadata(...)`, and `await _storageService.clearAllMetadata()`.
9. **`apps/vhunambi_client/lib/features/beats/presentation/providers/beats_provider.dart` (line 360)**:
   - Ensure `if (!mounted) return;` immediately follows `await _repository.publishBeat(id)`.
10. **`apps/vhunambi_client/lib/features/collections/presentation/providers/collections_provider.dart` (lines 180–190)**:
    - Mix in `SafeNotifierMixin<List<CollectionEntity>>` and use `setStateIfMounted(next)`.
11. **`apps/vhunambi_client/lib/features/creator_dna/presentation/providers/creator_dna_provider.dart` (lines 154–158)**:
    ```dart
  Future<void> resetDna() async {
    await _repo.clearAll();
    if (!mounted) return;
    _eventLog = [];
    state = CreatorDnaProfile.initial();
  }
    ```
12. **`apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart` (lines 278–293)**:
    - Mix in `SafeNotifierMixin<List<Track>>` and use `setStateIfMounted(...)`.
13. **`apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart` (lines 176–191)**:
    - Mix in `SafeNotifierMixin<List<NotificationEntity>>` and use `setStateIfMounted(...)`.
14. **`apps/vhunambi_client/lib/features/social/presentation/providers/creator_wallet_provider.dart` (lines 232–245) & `apps/vhunambi_client/lib/features/studio/presentation/providers/vocal_identity_provider.dart` (lines 405–406 & 416–448)**:
    - In `creator_wallet_provider.dart`: add `if (!mounted) return;` after `await _repo.getCreatorWallet(_creatorId)`.
    - In `vocal_identity_provider.dart`: add `if (!mounted) return;` after `await _recorder.startRecording(script)` (line 405) and after `await _recorder.stopRecording()` (line 416).

### 4.3 New File: `apps/vhunambi_client/lib/core/widgets/safe_network_avatar.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Error-resilient circular avatar widget (REQ-P65-L3-04).
///
/// Normalizes legacy/R2 URLs, attaches `onBackgroundImageError` to [CircleAvatar],
/// and falls back cleanly to creator initials or a [PhosphorIcon] on 404/codec error.
class SafeNetworkAvatar extends StatefulWidget {
  final String? imageUrl;
  final String fallbackLabel;
  final double radius;
  final Color? backgroundColor;

  const SafeNetworkAvatar({
    super.key = const Key('safe_network_avatar'),
    required this.imageUrl,
    required this.fallbackLabel,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  State<SafeNetworkAvatar> createState() => _SafeNetworkAvatarState();
}

class _SafeNetworkAvatarState extends State<SafeNetworkAvatar> {
  bool _hasError = false;

  @override
  void didUpdateWidget(covariant SafeNetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.imageUrl?.trim() ?? '';
    final normalizedUrl =
        raw.isEmpty ? '' : AppConstants.normalizeCloudMediaUrl(raw);
    final showImage = normalizedUrl.isNotEmpty && !_hasError;
    final trimmedLabel = widget.fallbackLabel.trim();
    final initial =
        trimmedLabel.isNotEmpty ? trimmedLabel[0].toUpperCase() : '';

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? AppColors.surfaceSecondary,
      backgroundImage: showImage ? NetworkImage(normalizedUrl) : null,
      onBackgroundImageError: showImage
          ? (Object exception, StackTrace? stackTrace) {
              if (mounted && !_hasError) {
                setState(() => _hasError = true);
              }
            }
          : null,
      child: !showImage
          ? KeyedSubtree(
              key: const Key('safe_network_avatar_fallback'),
              child: initial.isNotEmpty
                  ? Text(
                      initial,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const PhosphorIcon(
                      PhosphorIconsBold.user,
                      color: AppColors.brandPrimary,
                      size: 16,
                    ),
            )
          : null,
    );
  }
}
```

### 4.4 Surgical Updates: `explore_social_post_card.dart`, `pill_form.dart`, `studio_action_bar.dart` & `expanded_cockpit_modal.dart`

1. **`apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart` (lines 392–409)**:
   Replace raw `CircleAvatar(backgroundImage: NetworkImage(post.creatorAvatarUrl!))` with:
   ```dart
                      SafeNetworkAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceSecondary,
                        imageUrl: post.creatorAvatarUrl,
                        fallbackLabel: post.creatorName,
                      ),
   ```
2. **`apps/vhunambi_client/lib/features/player/presentation/widgets/pill_form.dart` (lines 108–124)**:
   Normalize `track.coverUrl` via `AppConstants.normalizeCloudMediaUrl` and bound `PaletteGenerator.fromImageProvider` with `.timeout(const Duration(seconds: 4))` inside `try/catch`.
3. **`apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart` (lines 218–233)**:
   Check `if (!context.mounted) return;` immediately after `await ref.read(lyricsReviewProvider.notifier).loadGeneratedLyrics(...)` **before** calling `formNotifier.markReviewingLyrics()`.
4. **`apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart` (lines 120–125)**:
   Wrap `_miniPlayerController.setNowPlayingOpen(false)` inside `try { ... } catch (_) {}` inside `Future.microtask` so disposal during container teardown never throws.

---

## 5. Milestone `M65.4` — Layer 4 `JsonSafe`, Per-Record Hive Quarantine, WebSocket Timeout & `DioException` Classification

### 5.1 New File: `apps/vhunambi_client/lib/core/utils/json_safe.dart`

```dart
import 'dart:convert';

import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';

/// Null-safe, non-throwing JSON decoding and coercion helpers (REQ-P65-L4-01).
abstract final class JsonSafe {
  /// Decodes a JSON string into a `Map<String, dynamic>`, returning `null`
  /// and recording a breadcrumb if [raw] is null, empty, or malformed.
  static Map<String, dynamic>? decodeMap(
    Object? raw, {
    String source = 'json_safe:decodeMap',
  }) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (error, stackTrace) {
        VhunambiCrashShield.recordBreadcrumb(
          source: source,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }

  /// Decodes a JSON string into a `List<dynamic>`, returning `null` on failure.
  static List<dynamic>? decodeList(
    Object? raw, {
    String source = 'json_safe:decodeList',
  }) {
    if (raw == null) return null;
    if (raw is List<dynamic>) return raw;
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (error, stackTrace) {
        VhunambiCrashShield.recordBreadcrumb(
          source: source,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return null;
  }

  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> asList(Object? value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }

  static String asString(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  static int asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static double asDouble(Object? value, [double fallback = 0.0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool asBool(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }
}
```

### 5.2 Surgical Update: `apps/vhunambi_client/lib/core/storage/sovereign_domain_repositories.dart`
In `WalletLedgerRepository.loadWalletSnapshot()` (lines 146–182), quarantine per-record `tx_` decoding with `JsonSafe.decodeMap` so a single corrupt transaction key never aborts loading the wallet snapshot:

```dart
  static Map<String, dynamic>? loadWalletSnapshot() {
    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      final snap = JsonSafe.decodeMap(
        box.get(_snapshotKey),
        source: 'wallet:snapshot',
      );
      if (snap != null) {
        final copy = Map<String, dynamic>.from(snap);
        final txs = <Map<String, dynamic>>[];
        for (final rawKey in box.keys) {
          final key = rawKey.toString();
          if (key.startsWith(_txPrefix)) {
            final parsedTx = JsonSafe.decodeMap(
              box.get(key),
              source: 'wallet:tx:$key',
            );
            if (parsedTx != null) {
              txs.add(Map<String, dynamic>.from(parsedTx));
            }
          }
        }
        txs.sort((a, b) {
          final da =
              DateTime.tryParse(JsonSafe.asString(a['timestamp'])) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db =
              DateTime.tryParse(JsonSafe.asString(b['timestamp'])) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        copy['transactions'] = txs;
        return copy;
      }
    }
    if (_memorySnapshot != null) {
      final txs = _memoryTransactions.values.toList()
        ..sort((a, b) {
          final da =
              DateTime.tryParse(JsonSafe.asString(a['timestamp'])) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db =
              DateTime.tryParse(JsonSafe.asString(b['timestamp'])) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
      return <String, dynamic>{..._memorySnapshot!, 'transactions': txs};
    }
    return null;
  }
```

### 5.3 Surgical Update: `apps/vhunambi_client/lib/features/studio/data/services/generation_socket_service.dart`
Add `connectTimeout = const Duration(seconds: 8)`, cancel prior `_socketSubscription` and `_pingTimer` at the start of `_doConnect`, and wrap heartbeat `socket.add` in `try/catch`:

```dart
  static const Duration connectTimeout = Duration(seconds: 8);
```
```dart
  Future<void> _doConnect(String generationId) async {
    if (_disposed) return;

    _pingTimer?.cancel();
    _pingTimer = null;
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      final targetWsBase = wsUrl ?? wsBaseUrl;
      final socket = await WebSocket.connect(
        '$targetWsBase?id=$generationId',
      ).timeout(connectTimeout);
      if (_disposed) {
        await socket.close(WebSocketStatus.normalClosure);
        return;
      }

      _reconnectAttempts = 0;
      _socket = socket;
      _startHeartbeat(socket);
      _socketSubscription = socket.listen(
        _onFrame,
        onError: (Object error) => _scheduleReconnect(generationId),
        onDone: () => _scheduleReconnect(generationId),
        cancelOnError: false,
      );
    } catch (error) {
      debugPrint('GenerationSocketService connect failed: $error');
      _scheduleReconnect(generationId);
    }
  }
```
```dart
  void _startHeartbeat(WebSocket socket) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (!isConnected) return;
      try {
        socket.add(jsonEncode(<String, String>{'type': 'PING'}));
        _resetPongTimer();
      } catch (error) {
        debugPrint('GenerationSocketService heartbeat send failed: $error');
        final generationId = _activeGenerationId;
        if (generationId != null) {
          _scheduleReconnect(generationId);
        }
      }
    });
  }
```

### 5.4 Surgical Update: `apps/vhunambi_client/lib/core/network/error_handler.dart`
Support `DioException` and `Object` in `NetworkErrorHandler.classify` and `toUserMessage`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

// Inside NetworkErrorHandler:
  ErrorType classify(Object error) {
    if (error is TimeoutException) {
      return ErrorType.timeout;
    }
    if (error is SocketException) {
      return ErrorType.noConnection;
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ErrorType.timeout;
        case DioExceptionType.connectionError:
          return ErrorType.noConnection;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          if (statusCode >= 500) return ErrorType.serverError;
          if (statusCode == 401) return ErrorType.unauthorized;
          if (statusCode == 403) return ErrorType.forbidden;
          if (statusCode == 404) return ErrorType.notFound;
          if (statusCode >= 400 && statusCode < 500) return ErrorType.clientError;
          return ErrorType.unknown;
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          if (error.error is SocketException) return ErrorType.noConnection;
          if (error.error is TimeoutException) return ErrorType.timeout;
          return ErrorType.unknown;
      }
    }
    if (error is ApiException) {
      final statusCode = error.statusCode;
      if (statusCode >= 500) return ErrorType.serverError;
      if (statusCode == 401) return ErrorType.unauthorized;
      if (statusCode == 403) return ErrorType.forbidden;
      if (statusCode == 404) return ErrorType.notFound;
      if (statusCode >= 400 && statusCode < 500) return ErrorType.clientError;
      return ErrorType.unknown;
    }
    if (error is HttpException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('timeout')) return ErrorType.timeout;
      if (msg.contains('connection') || msg.contains('network')) {
        return ErrorType.noConnection;
      }
      return ErrorType.serverError;
    }
    return ErrorType.unknown;
  }

  String toUserMessage(Object error) {
```

---

## 6. Milestone `M65.5` — Layer 5 Backend `GlobalErrorBoundary`, True PNG/WAV MIME Parity & Studio Parameter Fidelity

### 6.1 Surgical Update: `apps/vhunambi_api/src/server.ts`
Register global `app.onError` and `app.notFound` at the bottom of `server.ts`:

```typescript
// Phase 65 (REQ-P65-L5-01): Global JSON Error & NotFound Boundaries
app.onError((err, c) => {
  const statusCandidate = (err as { status?: number; statusCode?: number })
    ?.status ?? (err as { statusCode?: number })?.statusCode ?? 500;
  const status =
    statusCandidate >= 400 && statusCandidate < 600 ? statusCandidate : 500;
  const errorCode =
    (err as { code?: string })?.code ??
    (status === 400
      ? 'BAD_REQUEST'
      : status === 401
        ? 'UNAUTHORIZED'
        : status === 403
          ? 'FORBIDDEN'
          : status === 404
            ? 'NOT_FOUND'
            : 'INTERNAL_SERVER_ERROR');

  return c.json(
    {
      success: false,
      error: err.message || 'Unhandled server error',
      errorCode,
      message: err.message || 'Unhandled server error',
      path: c.req.path,
      timestamp: new Date().toISOString(),
    },
    status as 500,
  );
});

app.notFound((c) => {
  return c.json(
    {
      success: false,
      error: `Route not found: ${c.req.method} ${c.req.path}`,
      errorCode: 'NOT_FOUND',
      message: `Route not found: ${c.req.method} ${c.req.path}`,
      path: c.req.path,
      timestamp: new Date().toISOString(),
    },
    404,
  );
});
```

### 6.2 Surgical Update: `apps/vhunambi_api/src/modules/synthesis/r2_media_synthesizer.ts` & `vision_routes.ts`
Add `synthesizeCoverPngBytes(seedKey: string): Uint8Array` using `zlib.deflateSync` and IEEE 802.3 CRC32 so `.png` keys return genuine `\x89PNG\r\n\x1a\n` images (`Content-Type: image/png`), and increase master/default WAV duration from `4s`/`6s` to `24s` (tiled in $< 0.4\text{ ms}$ via `tileAndFadeWavBuffer`):

```typescript
import { deflateSync } from 'node:zlib';

const CRC32_TABLE = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) {
    c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  CRC32_TABLE[n] = c >>> 0;
}

function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    c = CRC32_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function buildPngChunk(typeAscii: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length, false);
  for (let i = 0; i < 4; i++) {
    out[4 + i] = typeAscii.charCodeAt(i);
  }
  out.set(data, 8);
  const crcVal = crc32(out.subarray(4, 8 + data.length));
  view.setUint32(8 + data.length, crcVal, false);
  return out;
}

/**
 * Generates a genuine RFC-2083 64x64 24-bit RGB PNG image with African
 * geometric ring gradients, compressed via zlib.deflateSync and CRC32 verified.
 */
export function synthesizeCoverPngBytes(seedKey: string): Uint8Array {
  const seed = hashSeed(seedKey);
  const width = 64;
  const height = 64;
  const palettes: Array<[number, number, number, number, number, number]> = [
    [245, 158, 11, 16, 185, 129],
    [139, 92, 246, 236, 72, 153],
    [6, 182, 212, 59, 130, 246],
    [234, 88, 12, 124, 58, 237],
  ];
  const [r1, g1, b1, r2, g2, b2] = palettes[seed % palettes.length];
  const seedPhase = seed % 7;

  const rowLen = 1 + width * 3;
  const rawScanlines = new Uint8Array(height * rowLen);
  let ptr = 0;
  for (let y = 0; y < height; y++) {
    rawScanlines[ptr++] = 0; // Filter type 0 (None)
    const ny = y / height;
    const dy = ny - 0.5;
    const dySq = dy * dy;
    const baseGradY = ny * 0.4;
    for (let x = 0; x < width; x++) {
      const nx = x / width;
      const dx = nx - 0.5;
      const distSq = dx * dx + dySq;
      const ring = 0.5 + 0.5 * fastSin(distSq * 64.0 - seedPhase);
      let mix = 0.65 * (nx * 0.6 + baseGradY) + 0.35 * ring;
      if (mix < 0) mix = 0;
      if (mix > 1) mix = 1;
      const invMix = 1 - mix;
      rawScanlines[ptr++] = (r1 * invMix + r2 * mix + 0.5) | 0;
      rawScanlines[ptr++] = (g1 * invMix + g2 * mix + 0.5) | 0;
      rawScanlines[ptr++] = (b1 * invMix + b2 * mix + 0.5) | 0;
    }
  }

  const ihdrData = new Uint8Array(13);
  const ihdrView = new DataView(ihdrData.buffer);
  ihdrView.setUint32(0, width, false);
  ihdrView.setUint32(4, height, false);
  ihdrData[8] = 8; // 8-bit depth
  ihdrData[9] = 2; // Truecolor RGB
  ihdrData[10] = 0;
  ihdrData[11] = 0;
  ihdrData[12] = 0;

  const compressedIdat = new Uint8Array(deflateSync(rawScanlines, { level: 6 }));
  const signature = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdrChunk = buildPngChunk('IHDR', ihdrData);
  const idatChunk = buildPngChunk('IDAT', compressedIdat);
  const iendChunk = buildPngChunk('IEND', new Uint8Array(0));

  const totalLen =
    signature.length + ihdrChunk.length + idatChunk.length + iendChunk.length;
  const pngOut = new Uint8Array(totalLen);
  let offset = 0;
  pngOut.set(signature, offset);
  offset += signature.length;
  pngOut.set(ihdrChunk, offset);
  offset += ihdrChunk.length;
  pngOut.set(idatChunk, offset);
  offset += idatChunk.length;
  pngOut.set(iendChunk, offset);

  return pngOut;
}
```

And in `synthesizeAndCacheMissingR2Object` (`r2_media_synthesizer.ts` lines 555–574):
```typescript
  if (
    lower.endsWith('.wav') ||
    lower.endsWith('.mp3') ||
    lower.endsWith('.m4a')
  ) {
    bytes = synthesizeStereoWavBytes({
      seedKey: cleanKey,
      durationSec: 24,
      sampleRate: 11025,
    });
    contentType = 'audio/wav';
  } else if (
    lower.endsWith('.png') ||
    lower.endsWith('.jpg') ||
    lower.endsWith('.jpeg')
  ) {
    bytes = synthesizeCoverPngBytes(cleanKey);
    contentType = 'image/png';
  } else if (lower.endsWith('.bmp')) {
    bytes = synthesizeCoverArtworkBytes(cleanKey);
    contentType = 'image/bmp';
  }
```

And in `synthesizeTrackStemPackWav` (`r2_media_synthesizer.ts` lines 331–332):
```typescript
  const stemDurationSec = Math.max(2, Math.min(32, options.stemDurationSec ?? 12));
  const masterDurationSec = Math.max(2, Math.min(32, options.masterDurationSec ?? 24));
```

### 6.3 Surgical Update: `apps/vhunambi_client/lib/features/studio/domain/services/studio_prompt_intelligence.dart` & `prompt_input_box.dart`
Pass `StudioFormState? currentForm` into `StudioPromptIntelligence.enhance` so explicit user selections (`90s Kwaito`, `Tshivenda` / `Tshivenḓa`) in the Studio form always take priority over `CreatorDnaProfile` defaults (`Afro Soul`, `English`):

```dart
// In studio_prompt_intelligence.dart:
import '../models/studio_form_state.dart';

  static PromptEnhancementResult enhance(
    String rawPrompt, {
    CreatorDnaProfile? dna,
    StudioFormState? currentForm,
  }) {
    if (rawPrompt.trim().isEmpty) {
      return PromptEnhancementResult(
        rawPrompt: rawPrompt,
        enhancedPrompt: '',
      );
    }

    final lower = rawPrompt.toLowerCase();
    final overrides = <String, dynamic>{};

    // 1. Explicit keyword detection in rawPrompt.
    for (final entry in _genreKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['genre'] = entry.value;
        break;
      }
    }

    for (final entry in _languageKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['language'] = entry.value;
        break;
      }
    }

    for (final entry in _vocalModeKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['vocalMode'] = entry.value;
        break;
      }
    }

    if (_femaleKeywords.any(lower.contains)) {
      overrides['vocalGender'] = 'female';
    } else if (_maleKeywords.any(lower.contains)) {
      overrides['vocalGender'] = 'male';
    }

    if (_moodUplifting.any(lower.contains)) {
      overrides['mood'] = 'Uplifting';
    } else if (_moodDark.any(lower.contains)) {
      overrides['mood'] = 'Melancholic';
    } else if (_moodSpiritual.any(lower.contains)) {
      overrides['mood'] = 'Peaceful';
    }

    // 2. Phase 65 (REQ-P65-L5-03): Active StudioFormState selections take
    // priority over CreatorDnaProfile defaults whenever the prompt did not
    // explicitly override them.
    if (currentForm != null) {
      if (currentForm.genre.trim().isNotEmpty) {
        final effectiveGenre = currentForm.productionEra != ProductionEra.modern
            ? '${currentForm.productionEra.label} ${currentForm.genre.trim()}'
            : currentForm.genre.trim();
        overrides.putIfAbsent('genre', () => effectiveGenre);
      }
      if (currentForm.language.trim().isNotEmpty) {
        overrides.putIfAbsent('language', () => currentForm.language.trim());
      }
      if (currentForm.mood.trim().isNotEmpty) {
        overrides.putIfAbsent('mood', () => currentForm.mood.trim());
      }
    }

    // 3. Merge DNA signals only for fields still left blank.
    if (dna != null && dna.onboardingCompleted) {
      final ranked = dna.topGenres(1);
      if (ranked.isNotEmpty) {
        overrides.putIfAbsent('genre', () => ranked.first);
      }
      if (dna.primaryLanguage.trim().isNotEmpty) {
        overrides.putIfAbsent('language', () => dna.primaryLanguage);
      }
    }
```

And in `apps/vhunambi_client/lib/features/studio/presentation/widgets/prompt_input_box.dart` (lines 121–135 & 176–192), pass `currentForm: ref.read(studioFormProvider)` into `StudioPromptIntelligence.enhance(...)`.

### 6.4 Surgical Update: `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`
Replace `generateLocalMockLyrics` (lines 260–299) so that it composes authentic, singable verses in the target language and genre **without** echoing the user's raw prompt phrase (`primaryPhrase`) into `[INTRO]`, `[VERSE 1]`, `[CHORUS]`, `[VERSE 2]`, or `[OUTRO]`:

```typescript
  const chorusRefrain = `${ chosenIdiom } — ${ kw0 } & ${ kw1 } in the ${ genre } groove`;

  const rawLyrics = `[INTRO]
${adLib0}
${adLib1}
Vhunambi (${VENDA_MUSICAL_TERMS.ngoma}) — ${langCtx.nativeName} ${genre} Session

[VERSE 1]
Step into the ${kw0} light, carried on a ${preset.defaultBpm} BPM tide
${kw1} and ${kw2} moving side by side
${chosenIdiom}
With ${grooveLine}

[PRE-CHORUS]
Feel ${kw2} rising in the chest, every heartbeat tuned in ${preset.defaultKey}
Hold onto ${kw3} till the dawn breaks bright and new
${adLib2}

[CHORUS]
${chorusRefrain}
Every voice answering together: ${secondaryIdiom}
From ${kw0} to the stars, we lift the ${genre} crown
Sing it in ${langCtx.nativeName}, let the ancestral groove stay deep

[VERSE 2]
Yesterday's echoes turn to ${kw2} gold inside the sound
${kw1} footsteps drumming sacred patterns on the ground
${secondaryIdiom}
Voices woven strong in ${langCtx.nativeName} harmony

[BRIDGE]
Strip it back to breath and sub-bass pulse (${kw3})
Hear ${kw0} whispering through the choir and the drums
${adLib3}

[OUTRO]
${adLib0} (${kw0} forever...)
${chosenIdiom} — the rhythm remains in motion.`;
```

### 6.5 Surgical Update: `tools/zr-studio-gpu/model_utils.py` & `tools/zr-studio-gpu/mmo_extractor.py`
Replace silent `except Exception: pass` blocks in `model_utils.py` (lines 106, 150, 162) and `mmo_extractor.py` (line 283) with explicit `[ZR-WARN]` diagnostic logs so RunPod worker logs surface LoRA or FFmpeg degradation immediately.

---

## 7. Full-Stack Phase 65 Automated Verification Suites

### 7.1 Flutter Verification Suite: `apps/vhunambi_client/test/phase65_foundation_crash_immunity_test.dart`

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/error_handler.dart';
import 'package:vhunambi_client/core/resilience/safe_audio_orchestrator.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';
import 'package:vhunambi_client/core/utils/json_safe.dart';
import 'package:vhunambi_client/core/widgets/safe_network_avatar.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/domain/services/studio_prompt_intelligence.dart';

class _TestAsyncNotifier extends StateNotifier<int> with SafeNotifierMixin<int> {
  _TestAsyncNotifier() : super(0);

  Future<bool> mutateAfterDelay(Duration delay, int nextVal) async {
    await Future<void>.delayed(delay);
    return setStateIfMounted(nextVal);
  }
}

void main() {
  setUp(() {
    VhunambiCrashShield.breadcrumbs.clear();
    SafeAudioOrchestrator.instance.resetForTesting();
  });

  test('T1 (REQ-P65-L1-01): ic_stat_music.xml exists and is valid vector drawable', () {
    final iconFile = File('android/app/src/main/res/drawable/ic_stat_music.xml');
    expect(iconFile.existsSync(), isTrue);
    final xml = iconFile.readAsStringSync();
    expect(xml, contains('<vector'));
    expect(xml, contains('android:width="24dp"'));
    expect(xml, contains('android:height="24dp"'));
    expect(xml, contains('#FFFFFF'));
  });

  test('T2 & T4 (REQ-P65-L1-02/04): VhunambiCrashShield contains platform errors & startup timeouts', () async {
    VhunambiCrashShield.installFrameworkHandlers();
    final handled = VhunambiCrashShield.recordPlatformError(
      StateError('Simulated native plugin failure'),
      StackTrace.current,
    );
    expect(handled, isTrue);
    expect(VhunambiCrashShield.breadcrumbs.length, greaterThanOrEqualTo(1));

    final fallbackVal = await VhunambiCrashShield.guardStartup<String>(
      stepName: 'hung_box',
      timeout: const Duration(milliseconds: 30),
      action: () async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return 'never_reached';
      },
      fallback: () => 'degraded_ok',
    );
    expect(fallbackVal, equals('degraded_ok'));
  });

  testWidgets('T3 (REQ-P65-L1-03): VhunambiSafeErrorCard renders with retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VhunambiSafeErrorCard(
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('vhunambi_safe_error_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('vhunambi_safe_error_retry_btn')));
    expect(retried, isTrue);
  });

  test('T5 (REQ-P65-L2-01): SafeAudioOrchestrator preempts competing engine slots', () async {
    var masterPaused = false;
    var stemPaused = false;

    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.masterPlayer,
      onPreemptPause: () async {
        masterPaused = true;
      },
    );
    expect(SafeAudioOrchestrator.instance.activeSlot, AudioEngineSlot.masterPlayer);

    await SafeAudioOrchestrator.instance.acquireSlot(
      AudioEngineSlot.stemMixer,
      onPreemptPause: () async {
        stemPaused = true;
      },
    );
    expect(masterPaused, isTrue);
    expect(SafeAudioOrchestrator.instance.activeSlot, AudioEngineSlot.stemMixer);

    await SafeAudioOrchestrator.instance.acquireSlot(AudioEngineSlot.reelPool);
    expect(stemPaused, isTrue);
    expect(SafeAudioOrchestrator.instance.activeSlot, AudioEngineSlot.reelPool);
  });

  test('T8 (REQ-P65-L2-04): PlayerNotifier boots paused at 0:00 and normalizes vhunambi.com URLs', () {
    final notifier = PlayerNotifier();
    addTearDown(notifier.dispose);
    expect(notifier.state.playbackStatus, PlaybackStatus.paused);
    expect(notifier.state.position, Duration.zero);

    final normalized = AppConstants.normalizeCloudMediaUrl(
      'https://vhunambi.com/audio/track_default_1.mp3',
      overrideOrigin: 'https://api.vhunambi.co.za',
    );
    expect(normalized, 'https://api.vhunambi.co.za/r2/audio/track_default_1.mp3');
  });

  test('T12 (REQ-P65-L3-03): SafeNotifierMixin prevents post-dispose state mutation', () async {
    final notifier = _TestAsyncNotifier();
    final future = notifier.mutateAfterDelay(
      const Duration(milliseconds: 40),
      99,
    );
    notifier.dispose();
    final updated = await future;
    expect(updated, isFalse);
  });

  testWidgets('T13 (REQ-P65-L3-04): SafeNetworkAvatar renders fallback initial when URL is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeNetworkAvatar(
            imageUrl: '',
            fallbackLabel: 'Makhadzi',
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('safe_network_avatar_fallback')), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
  });

  test('T14 & T17 (REQ-P65-L4-01/04): JsonSafe & NetworkErrorHandler classify DioException', () {
    expect(JsonSafe.decodeMap('{corrupt_json'), isNull);
    expect(JsonSafe.asInt('42'), 42);
    expect(JsonSafe.asDouble(null, 3.5), 3.5);

    const handler = NetworkErrorHandler();
    final dioTimeout = DioException(
      requestOptions: RequestOptions(path: '/v1/generations'),
      type: DioExceptionType.connectionTimeout,
    );
    expect(handler.classify(dioTimeout), ErrorType.timeout);
  });

  test('T18 (REQ-P65-L5-03): StudioPromptIntelligence prioritizes active Tshivenda + 90s Kwaito form over DNA defaults', () {
    final dna = CreatorDnaProfile.initial().copyWith(
      onboardingCompleted: true,
      genreWeights: const <String, double>{'Afro Soul': 5.0},
      primaryLanguage: 'English',
    );
    const activeForm = StudioFormState(
      genre: 'Kwaito',
      language: 'Tshivenḓa',
      productionEra: ProductionEra.era90s,
      mood: 'Energetic',
    );

    final res = StudioPromptIntelligence.enhance(
      'Street party anthem in the township',
      dna: dna,
      currentForm: activeForm,
    );

    expect(res.suggestedOverrides['genre'], '90s Kwaito');
    expect(res.suggestedOverrides['language'], 'Tshivenḓa');
    expect(res.enhancedPrompt, contains('with Tshivenḓa vocal delivery'));
    expect(res.enhancedPrompt, contains('crafted in the 90s Kwaito tradition'));
    expect(res.enhancedPrompt, isNot(contains('Afro Soul')));
    expect(res.enhancedPrompt, isNot(contains('English')));
  });
}
```

### 7.2 Backend Verification Suite: `apps/vhunambi_api/src/__tests__/phase65_foundation_resilience.test.ts`

```typescript
import { describe, expect, it } from 'vitest';
import { app } from '../server.js';
import {
  synthesizeAndCacheMissingR2Object,
  synthesizeCoverPngBytes,
} from '../modules/synthesis/r2_media_synthesizer.js';
import { generateLyricsWithLlm } from '../modules/lyrics/llm_handler.js';

describe('Phase 65 — Backend GlobalErrorBoundary, True PNG/WAV Parity & Lyrics Fidelity', () => {
  it('B1 (REQ-P65-L5-01): app.notFound returns canonical JSON error envelope', async () => {
    const res = await app.request('/v1/non-existent-phase65-endpoint');
    expect(res.status).toBe(404);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect(body.errorCode).toBe('NOT_FOUND');
  });

  it('B2 (REQ-P65-L5-02): synthesizeCoverPngBytes produces valid RFC-2083 PNG magic header and IEND chunk', async () => {
    const png = synthesizeCoverPngBytes('covers/test_phase65.png');
    expect(png.byteLength).toBeGreaterThan(128);
    // \x89PNG\r\n\x1a\n
    expect(Array.from(png.slice(0, 8))).toEqual([137, 80, 78, 71, 13, 10, 26, 10]);

    const r2Png = await synthesizeAndCacheMissingR2Object('visuals/default_9_16.png');
    expect(r2Png.contentType).toBe('image/png');
    expect(Array.from(r2Png.bytes.slice(0, 4))).toEqual([137, 80, 78, 71]);
  });

  it('B3 (REQ-P65-L5-02): synthesized R2 audio wav is 24 seconds long (never 3-4s stub)', async () => {
    const r2Wav = await synthesizeAndCacheMissingR2Object('audio/phase65_test_master.wav');
    expect(r2Wav.contentType).toBe('audio/wav');
    // 24s * 11025 Hz * 2 channels * 2 bytes = 1,058,400 bytes + 44 header
    expect(r2Wav.bytes.byteLength).toBeGreaterThanOrEqual(1058444);
  });

  it('B4 (REQ-P65-L5-04): generateLyricsWithLlm fallback does not parrot raw prompt instructions into stanzas', async () => {
    const rawPrompt =
      'Make a 90s kwaito song with heavy bassline and township whistles';
    const result = await generateLyricsWithLlm(rawPrompt, 'Kwaito', 'Tshivenda');
    expect(result.rawLyrics).toContain('[INTRO]');
    expect(result.rawLyrics).toContain('[VERSE 1]');
    expect(result.rawLyrics).toContain('[CHORUS]');
    expect(result.rawLyrics).not.toContain(`Thinking of ${rawPrompt}`);
    expect(result.rawLyrics).not.toContain(`we move through ${rawPrompt}`);
  });
});
```
