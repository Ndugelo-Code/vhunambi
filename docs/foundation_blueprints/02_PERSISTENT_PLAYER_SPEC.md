# Blueprint 02: Persistent Audio Player Specification (`02_PERSISTENT_PLAYER_SPEC.md`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS)  
> **Core Packages:** `just_audio`, `audio_service`, `audio_session`, `flutter_riverpod`  
> **Scope:** Persistent Mini-Player Dock, Expanded Audio Cockpit, Lock-Screen Media Controls, Riverpod State Engine

---

## 1. Visual Specification & Dock Scaffolding

The Vhunambi audio player operates as a globally mounted, persistent daemon. The audio pipeline never unmounts or interrupts playback during screen navigation, modal presentations, or tab switches.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ [████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] │ <-- 2px Progress Bar
│ ┌────┐  Grateful in the Light                                             [❤️ 1002] (▶) │ <-- Mini-Player Dock
│ │ 🎹 │  Sigwa & Inaf • Amapiano • 3:36                                                  │     (64px height)
│ └────┘                                                                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│    [Home]          [Explore]          [✨ Create]          [Library]          [Market]    │ <-- Bottom Navigation Bar
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Mini-Player Dock (Bottom Persistent Bar)

* **Mounting Position:** Statically positioned directly above the bottom navigation bar dock (`bottom: 0` or nested above `BottomNavigationBar` / `NavigationRail` for Desktop).
* **Dimensions:**
  * Height: `64px`.
  * Width: `100%` full viewport width.
  * Padding: `horizontal: 12px`, `vertical: 8px`.
* **Container Surface:**
  * Background: `#141418` (`AppColors.surfaceElevated`).
  * Border: `1px solid #2D2D38` on top border only.
  * Elevation / Shadow: `BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: Offset(0, -2))`.
* **Real-time Progress Indicator:**
  * Mounted at the very top edge of the mini-player (`top: 0`, `height: 2px`, full width).
  * Active Elapsed Color: `#F97316` (`AppColors.brandPrimary`).
  * Buffer Color: `#4B5563` (`AppColors.borderActive`).
  * Inactive Track Color: `#2D2D38` (`AppColors.borderSubtle`).
* **Leading Track Artwork (`48x48px`):**
  * Radius: `8px` (`BorderRadius.circular(8)`).
  * Cover Asset: High-resolution cached thumbnail or dynamic African genre gradient with centered instrument vector icon (e.g., piano, log drum, acoustic guitar).
  * Interactive Tap: Tapping anywhere on the leading artwork or metadata column expands the **Expanded Full-Screen Player Modal**.
* **Metadata Stack (Centered Flexible Column):**
  * CrossAxisAlignment: `CrossAxisAlignment.start`.
  * Title Row: `"Grateful in the Light"` (`fontSize: 14`, `fontWeight: FontWeight.w600`, `color: #FFFFFF`, `overflow: TextOverflow.ellipsis`, maxLines: 1).
  * Subtitle Row: `"Sigwa & Inaf • Amapiano • 3:36"` (`fontSize: 12`, `color: #9CA3AF`, `overflow: TextOverflow.ellipsis`, maxLines: 1).
* **Social Stat Action (`Like Button`):**
  * Heart icon (`Icons.favorite_border_rounded` when unliked, `Icons.favorite_rounded` with `#EF4444` when liked).
  * Like Count label: `"1002"` (`fontSize: 12`, `color: #9CA3AF`).
  * Padding: `horizontal: 8px`.
* **Primary Play/Pause Trigger:**
  * Circular Button: `36x36px` circular container, solid `#F97316` fill (`AppColors.brandPrimary`).
  * Icon Glyph: Pure Black `#000000` (`Icons.play_arrow_rounded` or `Icons.pause_rounded`, `size: 20`).
  * Hit Target: Minimum `44x44px` accessible touch target.

---

### 1.2 Expanded Full-Screen Audio Cockpit Modal

Invoked via swipe-up gesture or tap on the mini-player dock. Renders as an elevated modal sheet or full-screen route with hero transitions:

```
┌────────────────────────────────────────────────────────┐
│                        [  ━  ]                         │ <-- Centered Drag Handle (36x4px)
│                                                        │
│  [ v ]                Now Playing               [ ⋯ ]  │ <-- Top Bar (Dismiss + Options)
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │                                                  │  │
│  │                 [ 🎹 VECTOR ART ]                │  │ <-- 1:1 Aspect Ratio Hero Card
│  │                                                  │  │     (24px corner radius)
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  Grateful in the Light                       [❤️]      │ <-- Title & Verified Badge
│  Sigwa & Inaf [✓] • Amapiano                 [↗]      │ <-- Creator & Share Action
│                                                        │
│  [ ılılıllı|ı|ı|lılıl|lılıllı|ı|ı|lılıl|lılıllı|ı|ı ]  │ <-- Interactive Waveform Scrubber
│  01:24                                           03:36 │ <-- Elapsed / Remaining Timestamps
│                                                        │
│    [🔀]     [⏮️]       (  ▶  )       [⏭️]       [🔁]    │ <-- Transport Controls (64px Orb)
│                                                        │
│       [ 🎤 Lyrics ]    [ 🎚️ Stems ]    [ ⬇️ Export ]    │ <-- Utility Tray
└────────────────────────────────────────────────────────┘
```

#### Detailed Element Specifications:
1. **Modal Container:**
   * Background: `#0A0A0C` canvas with `#16161C` gradient depth (`surfaceModal`).
   * Top Corners: `BorderRadius.vertical(top: Radius.circular(24))`.
2. **Dismiss Handle:**
   * Centered pill (`width: 36px`, `height: 4px`, color: `#4B5563`, radius: `9999px`).
3. **Hero Artwork Showcase:**
   * Aspect Ratio: `1:1` square, horizontally centered with `24px` horizontal screen margin.
   * Border Radius: `24px`.
   * Background: Dynamic African regional gradient (e.g., Amapiano Ochre/Gold `#D97706` $\rightarrow$ `#F59E0B`).
   * Artwork Graphic: Centered high-resolution vector emblem or generative AI artwork.
   * Ambient Glow: `BoxShadow(color: dominantColor.withOpacity(0.35), blurRadius: 40, spreadRadius: -10)`.
4. **Track Information & Verified Badge:**
   * Title: `fontSize: 22`, `fontWeight: FontWeight.bold`, `color: #FFFFFF`.
   * Creator Row: Creator name (`fontSize: 16`, `color: #9CA3AF`) with verified checkmark badge (`Icons.verified_rounded`, `#F97316`, `size: 16`).
   * Actions: Heart toggle (`size: 24`), Share sheet button (`Icons.ios_share_rounded` / `share_rounded`).
5. **Interactive Waveform Scrubber:**
   * Visualization: Dynamic 48-bar waveform profile reflecting track loudness envelope.
   * Bar Heights: Scaled dynamically (`8px` to `36px`), radius `2px`.
   * Color Split: Elapsed bars painted in `#F97316`; upcoming bars in `#2D2D38`.
   * Drag Behavior: Continuous scrubbing with seek preview and haptic feedback (`HapticFeedback.selectionClick()`).
   * Timestamps Row: Left label `${elapsed}` (`fontSize: 12`, `#9CA3AF`); Right label `${duration}` (`fontSize: 12`, `#9CA3AF`).
6. **DAW Transport Control Deck:**
   * **Shuffle:** `Icons.shuffle_rounded` (Inactive: `#6B7280`, Active: `#F97316`).
   * **Skip Previous:** `Icons.skip_previous_rounded` (`size: 32`, `#FFFFFF`).
   * **Primary Play/Pause Orb:** `64x64px` circular button, background `#F97316`, shadow `0 6px 20px rgba(249, 115, 22, 0.4)`, icon `Icons.play_arrow_rounded` / `Icons.pause_rounded` (`size: 36`, color: `#000000`).
   * **Skip Next:** `Icons.skip_next_rounded` (`size: 32`, `#FFFFFF`).
   * **Repeat / Loop:** `Icons.repeat_rounded` / `Icons.repeat_one_rounded` (Inactive: `#6B7280`, Active: `#F97316`).
7. **Track Utility Tray (Glassmorphic Bottom Bar):**
   * **Lyrics Sheet:** `Icons.lyrics_outlined` + `"Lyrics"` (opens synchronized lyric bottom sheet).
   * **Stem Separation:** `Icons.tune_rounded` + `"Stems"` (opens AI stem mute/solo mixing panel).
   * **Download / Export:** `Icons.download_rounded` + `"Export"` (downloads offline master FLAC/MP3).

---

## 2. State Management Architecture (Flutter Riverpod)

```
┌─────────────────────────────────────────────────────────────┐
│                       UI Layer                              │
│       [MiniPlayerDock]            [ExpandedAudioCockpit]    │
└──────────────────────────────┬──────────────────────────────┘
                               │ ref.watch(playerStateProvider)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 PlayerNotifier (Riverpod)                   │
│        - play(Track)          - seek(Duration)              │
│        - pause()              - toggleShuffle()             │
│        - next() / previous()  - setRepeatMode()             │
└──────────────────────────────┬──────────────────────────────┘
                               │ AudioHandler API
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              VhunambiAudioHandler (Headless)                │
│    (Wraps just_audio AudioPlayer & audio_service bridge)    │
├──────────────────────────────┬──────────────────────────────┤
│   Native Audio Session       │   Lock Screen / Notification │
│   (Android/iOS/macOS/Win)    │   (NowPlaying & MediaKeys)   │
└──────────────────────────────┴──────────────────────────────┘
```

### 2.1 Immutable State Models

```dart
// lib/features/player/domain/models/player_state.dart
import 'package:flutter/foundation.dart';

enum PlaybackStatus { idle, buffering, playing, paused, completed, error }
enum RepeatMode { off, all, one }

@immutable
class TrackEntity {
  final String id;
  final String title;
  final String creatorName;
  final String creatorAvatarUrl;
  final String audioUrl;
  final String coverUrl;
  final String genre;
  final String language;
  final Duration duration;
  final int likeCount;
  final int playCount;
  final List<double> waveformData;

  const TrackEntity({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.creatorAvatarUrl,
    required this.audioUrl,
    required this.coverUrl,
    required this.genre,
    required this.language,
    required this.duration,
    this.likeCount = 0,
    this.playCount = 0,
    this.waveformData = const [],
  });
}

@immutable
class PlayerState {
  final TrackEntity? currentTrack;
  final PlaybackStatus playbackStatus;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final List<TrackEntity> queue;
  final int currentIndex;
  final bool isShuffle;
  final RepeatMode repeatMode;
  final String? errorMessage;

  const PlayerState({
    this.currentTrack,
    this.playbackStatus = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.isShuffle = false,
    this.repeatMode = RepeatMode.off,
    this.errorMessage,
  });

  bool get isPlaying => playbackStatus == PlaybackStatus.playing;
  bool get hasActiveTrack => currentTrack != null;
  double get progressRatio {
    if (duration.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    TrackEntity? currentTrack,
    PlaybackStatus? playbackStatus,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    List<TrackEntity>? queue,
    int? currentIndex,
    bool? isShuffle,
    RepeatMode? repeatMode,
    String? errorMessage,
  }) {
    return PlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      errorMessage: errorMessage,
    );
  }
}
```

### 2.2 Riverpod StateNotifier Contract

```dart
// lib/features/player/presentation/providers/player_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerStateProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final audioHandler = ref.watch(audioHandlerProvider);
  return PlayerNotifier(audioHandler);
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final VhunambiAudioHandler _audioHandler;

  PlayerNotifier(this._audioHandler) : super(const PlayerState()) {
    _bindAudioStreams();
  }

  void _bindAudioStreams() {
    _audioHandler.playbackState.listen((playbackState) {
      // Map audio_service playbackState to PlayerState
    });

    _audioHandler.mediaItem.listen((mediaItem) {
      // Map audio_service MediaItem to currentTrack
    });
  }

  Future<void> playTrack(TrackEntity track, {List<TrackEntity>? queue}) async {
    // 1. Update queue in audio handler
    // 2. Load audio URL & initiate playback
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration targetPosition) async {
    await _audioHandler.seek(targetPosition);
  }

  Future<void> skipToNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _audioHandler.skipToPrevious();
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeatMode() {
    final nextMode = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }
}
```

---

## 3. Headless Audio Service & Platform Native Behavior

To guarantee uninterrupted audio across mobile lock screens and desktop environments, playback is orchestrated via a `BaseAudioHandler` subclass:

```dart
// lib/core/audio/vhunambi_audio_handler.dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class VhunambiAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  VhunambiAudioHandler() {
    _initEventForwarding();
  }

  void _initEventForwarding() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final isPlaying = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();
}
```

---

## 4. Platform Native Adaptations

### 4.1 Mobile (iOS & Android)
* **Audio Session Management (`audio_session`):**
  * Configure session for music: `AudioSession.instance.then((s) => s.configure(const AudioSessionConfiguration.music()))`.
  * **Interruption Handling:** Auto-pause when a phone call is received; auto-resume if configured upon call termination.
  * **Headphone Unplug / Bluetooth Disconnect:** Automatic pause when `becomingNoisy` stream emits to protect user privacy in public settings.
* **Lock Screen & Dynamic Island:**
  * Displays track title, artist name, dynamic cover art, elapsed timeline scrubber, and skip/scrub triggers via native `MPNowPlayingInfoCenter` (iOS) and `MediaNotification` (Android).

### 4.2 Desktop (Windows & macOS)
* **Global Hardware Media Keys:**
  * Seamless binding to keyboard play/pause, next track, and previous track buttons via `audio_service` Windows background session integration.
* **Keyboard Shortcuts:**
  * `Space`: Toggle play/pause (when not focused on text input fields).
  * `Left Arrow` / `Right Arrow` (with `Alt`): Seek backward/forward 5 seconds.
  * `M`: Toggle mute.
* **Cursor & Hover States:**
  * Interactive waveform and progress bars show timestamp tooltips on mouse hover.
  * Drag handles show custom resizing/hand cursors (`SystemMouseCursors.click`).
