# Blueprint 07: Extended Audio Transport, Generation Pipeline & Modals Specification (`07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS, Web)  
> **Components Covered:**  
> - Desktop Extended DAW Audio Transport Bar (>1024px)  
> - Mobile Mini-Player Strip (<768px)  
> - Real-Time Audio Generation Pipeline Card (`Result` Panel)  
> - In-App Notifications Drawer / Popover  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com`)

---

## 1. Desktop Extended Audio Transport Bar (> 1024px)

The Desktop Extended Audio Transport Bar is mounted persistently at the bottom of the viewport, spanning 100% width. It serves as a comprehensive digital audio workstation (DAW) transport console for continuous music streaming, playlist queue management, and tempo/pitch manipulation.

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [██████████████████████████████████████████████████████████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] │ <-- 2px Progress Line
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ┌────┐ Ndo Mufuna Matibe                                                                                             │
│ │ 🎹 │ Amapiano • 3:14 / 3:18  [ ılıl|lılıllı ]   [⏮]  ( ▶ )  [⏭]    [🔁] [⏱️] [⬇] [➕] [📑]   [🔊] [━━━━●━━] [^] [v] [✕] │
│ └────┘                                                                                                               │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Structural Metrics & Top Progress Line
* **Mounting:** `Positioned(bottom: 0, left: 0, right: 0)`.
* **Height:** `72px` desktop.
* **Surface Background:** `#0A0A0C` to `#141418` dark gradient with `1px solid #2D2D38` top border.
* **Persistent Top Progress Line:**
  * Height: `2px`.
  * Active Elapsed Color: Solid `#F97316` (`brandPrimary`).
  * Buffer / Inactive Color: `#2D2D38` (`borderSubtle`).
  * Hit Target: Expandable to `6px` on mouse hover with scrub thumb and timestamp preview tooltip.

---

### 1.2 Track Metadata & Active Amplitude Visualizer
* **Leading Album Artwork (`48x48px`):**
  * Radius: `8px` (`BorderRadius.circular(8)`).
  * Asset: Dynamic African genre gradient cover with centered instrument vector icon.
* **Metadata Stack:**
  * Title: `"Ndo Mufuna Matibe"` (`fontSize: 14`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  * Sub-label: `"Amapiano • 3:14 / 3:18"` (`fontSize: 12`, `color: #9CA3AF`).
* **Active Amplitude Equalizer Bars:**
  * Position: Inline immediately to the right of the metadata column.
  * Representation: 8 animated vertical bars (`width: 3px`, `height: 8px to 22px`, `radius: 1.5px`, color: `#F97316`).
  * Animation: Real-time amplitude pulse tied to `just_audio` player state or simulated audio frame ticker when playing; static when paused.

---

### 1.3 Full DAW Transport & Utility Control Cluster

```
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [⏮]    (  ▶  )    [⏭]   │   [🔁]   [⏱️]   [⬇]   [➕]   [📑]   │   [🔊] [━━━━●━━]   [^]   [v]   [✕] │
│   Primary Playback     │        Utility & Queue         │     Levels & Window Controls      │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

1. **Primary Playback Group:**
   * `Skip Previous` (`Icons.skip_previous_rounded`, `size: 24`, `#FFFFFF`).
   * `Play / Pause Orb`: Circular button (`40x40px`, solid `#F97316` amber fill, pure black glyph `#000000`, `Icons.play_arrow_rounded` / `Icons.pause_rounded`).
   * `Skip Next` (`Icons.skip_next_rounded`, `size: 24`, `#FFFFFF`).
2. **DAW Utility & Queue Group:**
   * `🔁 Repeat / Loop Mode`: Cycles between `Off`, `Repeat All`, and `Repeat One` (Active: `#F97316`).
   * `⏱️ Playback Speed / Pitch`: Speedometer icon (`speed_rounded`) toggling speed popover (`0.75x`, `1.0x`, `1.25x`, `1.5x`).
   * `⬇️ Direct Download`: One-tap MP3 audio master download (`file_download_outlined`).
   * `➕ Add to Playlist`: Opens playlist picker bottom sheet (`playlist_add_rounded`).
   * `📑 Queue Drawer`: Opens right-hand side sliding drawer showing upcoming track queue (`queue_music_rounded`).
3. **Audio Levels & Window Controls:**
   * `🔊 Volume Control`: Speaker icon + interactive horizontal orange slider (`width: 90px`, `activeColor: #F97316`, `inactiveColor: #2D2D38`).
   * `^ Expand`: Expands full-screen audio cockpit (`keyboard_arrow_up_rounded`).
   * `v Minimize`: Collapses transport bar into minimized pill dock.
   * `✕ Dismiss`: Closes and unmounts the active audio session (`close_rounded`).

---

## 2. Mobile Mini-Player Strip (< 768px)

Mounted persistently directly above the 5-tab bottom navigation rail on mobile devices:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ [████████████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] │ <-- 2px Progress Line
├─────────────────────────────────────────────────────────────────────────────────┤
│ ┌────┐  Grateful in the Light                                                   │
│ │ 🎹 │  Amapiano • 0:13 / 3:29                       [⏮]   ( ▶ )   [⏭]    [✕]   │
│ └────┘                                                                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│    [Home]          [Explore]          [✨ Create]          [Library]   [Market]  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

* **Positioning:** Fixed directly above bottom nav (`bottom: 64px`, `height: 60px`, width: `100%`).
* **Surface:** Solid `#141418` (`surfaceElevated`), top border `1px solid #2D2D38`.
* **Leading Thumbnail:** `40x40px` rounded square (`8px` radius) with instrument vector artwork.
* **Metadata Column:**
  * Title: `"Grateful in the Light"` (`fontSize: 13`, `fontWeight: FontWeight.w600`, `#FFFFFF`, single-line ellipsis).
  * Subtitle: `"Amapiano • 0:13 / 3:29"` (`fontSize: 11`, `color: #9CA3AF`).
* **Compact Controls:**
  * `⏮ Previous`: `Icons.skip_previous_rounded` (`size: 20`, `#FFFFFF`).
  * `Play / Pause Orb`: Circular button (`36x36px`, solid `#F97316`, black icon `#000000`, `size: 20`).
  * `⏭ Next`: `Icons.skip_next_rounded` (`size: 20`, `#FFFFFF`).
  * `✕ Dismiss`: `Icons.close_rounded` (`size: 16`, `#6B7280`).
* **Gesture:** Tap anywhere on metadata or artwork opens the full-screen modal cockpit.

---

## 3. Real-Time Audio Generation Pipeline Card (`Result` Panel)

Rendered in the Studio Cockpit immediately after submitting a song generation prompt. Displays live multi-stage worker progress with context-aware drum synthesis status messages:

```
┌────────────────────────────────────────────────────────────────────────┐
│ Result                                                    🔄 New song  │
│                                                                        │
│ rave                                                    🔄 Generating  │
│ [ Gqom ]                                                               │
│                                                                        │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │                                                                    │ │
│ │                        lılıllı|ı|ı|lılıl                           │ │ <-- Equalizer Bars
│ │                                                                    │ │
│ │               Laying down the drums... feel it building 🥁          │ │ <-- Dynamic Message
│ │                                                                    │ │
│ │   (✓)  Starting up...                                              │ │ <-- Step 1 Completed
│ │                                                                    │ │
│ │   (✓)  Writing lyrics...                                           │ │ <-- Step 2 Completed
│ │                                                                    │ │
│ │   (↻)  Producing the beat...                                       │ │ <-- Step 3 Active Spinner
│ │                                                                    │ │
│ │   (4)  Your song is ready!                                         │ │ <-- Step 4 Pending
│ │                                                                    │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│ ⌄ Show lyrics                                                          │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 3.1 Card Architecture & Visual Equalizer
* **Header Row:**
  * Left: `"Result"` (`fontSize: 14`, `fontWeight: FontWeight.w600`, `#9CA3AF`).
  * Right: `"🔄 New song"` (resets form for a new generation).
* **Track Title & Status Badges:**
  * Title: `"rave"` (`fontSize: 22`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Genre Badge: `[ Gqom ]` (`background: #1B1B22`, border `1px solid #2D2D38`, `fontSize: 12`, `#F97316`).
  * Generation Badge: `[ 🔄 Generating ]` (Amber pill badge with rotating circular arrow glyph).
* **Worker Visual Synthesis Equalizer:**
  * 11 vertical rounded bars arranged in a center-peaked wave pattern.
  * Color: Vibrant amber `#F97316`.
  * Animation: Procedural sine-wave bounce indicating active RunPod worker synthesis.
* **Dynamic Contextual Message:**
  * Typography: `fontSize: 14`, `fontWeight: FontWeight.w600`, `#F59E0B`, centered.
  * Dynamic African Rhythm Strings:
    * Amapiano: *"Dialing in the log drum baseline... 🎹"*
    * Gqom: *"Laying down the drums... feel it building 🥁"*
    * Maskandi: *"Tuning the acoustic picking... 🎸"*
    * Vocal Sync: *"Harmonizing vocal layers in Tshivenḓa... 🎤"*

---

### 3.2 4-Step Synthesis State Machine

| Step | State Label | Visual Indicator | Status Description |
| :---: | :--- | :--- | :--- |
| **1** | `Starting up...` | Filled orange circle with white checkmark `(✓)` | Inference worker allocated on GPU cluster |
| **2** | `Writing lyrics...` | Filled orange circle with white checkmark `(✓)` | Indigenous language dialect model generates stanzas |
| **3** | `Producing the beat...` | Animated circular orange ring spinner `(↻)` | Audio diffusion pipeline synthesizes stems & mix |
| **4** | `Your song is ready!` | Dark numbered circle `(4)` / Checkmark `(✓)` | Master audio encoded to MP3, waveform analyzed |

* **Live Lyrics Inspection Drawer:**
  * Toggle trigger: `⌄ Show lyrics` (`color: #F97316`, `fontSize: 13`).
  * Expands an inline preview of generated verse/chorus stanzas while the audio beat is rendering.

---

## 4. In-App Notifications Drawer / Popover

Triggered when the user taps the top-bar notification bell (`🔔`):

```
┌────────────────────────────────────────────────────────┐
│ 🔔 Notifications  [ 2 ]                    ✓ Mark all read │
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌───┐  Your song "ZaYN" is ready!                ● │ │ <-- Unread Dot (#F97316)
│ │ │ 🎵│  9 minutes ago                               │ │
│ │ └───┘                                              │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌───┐  Your song "ZaYN" is ready!                ● │ │
│ │ │ 🎵│  9 minutes ago                               │ │
│ │ └───┘                                              │ │
│ └────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────┤
│ View all notifications                           Close │
└────────────────────────────────────────────────────────┘
```

* **Header Scaffolding:**
  * Bell Icon + Title: `"Notifications"` (`fontSize: 16`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Unread Counter Badge: `[ 2 ]` (Solid orange circle, `fontSize: 11`, pure black text `#000000`).
  * Header Action: `"✓ Mark all read"` (`color: #9CA3AF`, `fontSize: 12`, hover `#FFFFFF`).
* **Notification Card Item:**
  * Background: `#141418` (`surfaceElevated`), border `1px solid #2D2D38`, border-radius `12px`, padding `12px`.
  * Leading Icon: Circular container (`36x36px`, surface `#1B1B22`) with musical note glyph (`#F97316`).
  * Title: `"Your song \"ZaYN\" is ready!"` (`fontSize: 14`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  * Timestamp: Relative time string (`"9 minutes ago"`, `fontSize: 12`, `#6B7280`).
  * Unread Indicator: Solid orange dot (`8x8px`, `#F97316`) on the trailing edge.
  * Tap Action: Opens the Track Details page (`/track/{id}`) and initiates immediate playback.
* **Footer Row:**
  * Left: `"View all notifications"` (Text link, `#F97316`, `fontSize: 13`).
  * Right: `"Close"` (Dismisses popover, `#9CA3AF`, `fontSize: 13`).

---

## 5. Riverpod State Models & Service Bridges

```dart
// lib/features/studio/domain/models/generation_pipeline_state.dart
import 'package:flutter/foundation.dart';
import '../../player/domain/models/player_state.dart';

enum PipelineStep { startingUp, writingLyrics, producingBeat, ready, failed }

@immutable
class GenerationProgressState {
  final String generationId;
  final String trackTitle;
  final String genre;
  final PipelineStep currentStep;
  final String statusMessage;
  final double progressPercent;
  final String? generatedLyrics;
  final TrackEntity? completedTrack;
  final String? errorMessage;

  const GenerationProgressState({
    required this.generationId,
    required this.trackTitle,
    required this.genre,
    this.currentStep = PipelineStep.startingUp,
    this.statusMessage = 'Starting up...',
    this.progressPercent = 0.1,
    this.generatedLyrics,
    this.completedTrack,
    this.errorMessage,
  });

  bool get isGenerating => currentStep != PipelineStep.ready && currentStep != PipelineStep.failed;
  bool get isReady => currentStep == PipelineStep.ready;
}
```

### In-App Notification Entity

```dart
// lib/features/notifications/domain/models/notification_entity.dart
import 'package:flutter/foundation.dart';

@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;
  final String? targetTrackId;
  final DateTime createdAt;
  final bool isRead;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    this.targetTrackId,
    required this.createdAt,
    this.isRead = false,
  });
}
```

### Riverpod Providers Contract

```dart
// lib/features/studio/presentation/providers/generation_pipeline_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/generation_pipeline_state.dart';
import '../../notifications/domain/models/notification_entity.dart';

final generationProgressProvider = StateNotifierProvider<GenerationPipelineNotifier, GenerationProgressState?>((ref) {
  return GenerationPipelineNotifier();
});

class GenerationPipelineNotifier extends StateNotifier<GenerationProgressState?> {
  GenerationPipelineNotifier() : super(null);

  void startGeneration({required String title, required String genre}) {
    state = GenerationProgressState(
      generationId: DateTime.now().millisecondsSinceEpoch.toString(),
      trackTitle: title,
      genre: genre,
      currentStep: PipelineStep.startingUp,
      statusMessage: 'Allocating GPU synthesis worker...',
      progressPercent: 0.15,
    );
  }

  void updateStep(PipelineStep step, String message, double progress) {
    state = state?.copyWith(
      currentStep: step,
      statusMessage: message,
      progressPercent: progress,
    );
  }

  void complete(TrackEntity track) {
    state = state?.copyWith(
      currentStep: PipelineStep.ready,
      statusMessage: 'Your song is ready!',
      progressPercent: 1.0,
      completedTrack: track,
    );
  }
}

final notificationsProvider = StateProvider<List<NotificationEntity>>((ref) => [
  NotificationEntity(
    id: '1',
    title: 'Your song "ZaYN" is ready!',
    message: 'House • 3:20',
    targetTrackId: 'track_zayn_1',
    createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
    isRead: false,
  ),
  NotificationEntity(
    id: '2',
    title: 'Your song "ZaYN" is ready!',
    message: 'House • 3:20',
    targetTrackId: 'track_zayn_2',
    createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
    isRead: false,
  ),
]);
```
