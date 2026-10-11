# Phase 22 · Technical Design — Heritage Crate Digging & Native Video Muxer

> **Phase:** 22  
> **Codename:** `heritage-crate-and-video-muxer`  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))

---

## 1. Track A: Domain Architecture & Riverpod Providers

### 1.1 `HeritageSampleEntity` & `HeritageCrateCategory`
**File:** `lib/features/studio/domain/models/heritage_crate_models.dart`

```dart
enum HeritageCrateCategory {
  all('All Instruments', '🌍'),
  percussion('Drums & Percussion', '🥁'),
  pluckedStrings('Plucked Strings', '🪕'),
  melodicIdiophones('Idiophones & Mbira', '🎹'),
  traditionalPipes('Flutes & Horns', '🎷'),
  chants('Ancestral Chants', '🗣️');

  final String label;
  final String emoji;
  const HeritageCrateCategory(this.label, this.emoji);
}

class HeritageSampleEntity {
  final String id;
  final String name;
  final String instrument;
  final String cultureRegion;
  final String audioUrl;
  final int bpm;
  final String rootKey;
  final double durationSec;
  final List<String> tags;
  final bool isFavorite;
  final List<double> waveformPeaks;

  const HeritageSampleEntity({
    required this.id,
    required this.name,
    required this.instrument,
    required this.cultureRegion,
    required this.audioUrl,
    required this.bpm,
    required this.rootKey,
    required this.durationSec,
    required this.tags,
    this.isFavorite = false,
    this.waveformPeaks = const [0.3, 0.6, 0.9, 0.4, 0.7, 0.8, 0.5, 0.2],
  });

  HeritageSampleEntity copyWith({bool? isFavorite}) {
    return HeritageSampleEntity(
      id: id,
      name: name,
      instrument: instrument,
      cultureRegion: cultureRegion,
      audioUrl: audioUrl,
      bpm: bpm,
      rootKey: rootKey,
      durationSec: durationSec,
      tags: tags,
      isFavorite: isFavorite ?? this.isFavorite,
      waveformPeaks: waveformPeaks,
    );
  }
}
```

### 1.2 `MpcPadEntity` & `MpcSlicerState`
**File:** `lib/features/studio/domain/models/heritage_crate_models.dart`

```dart
class MpcPadEntity {
  final String id;
  final int index; // 0 to 7
  final String label;
  final String sourceAudioUrl;
  final double startSec;
  final double endSec;
  final int pitchShiftSemitones; // -12 to +12
  final bool isReversed;
  final double volume; // 0.0 to 1.5
  final bool isMuted;
  final bool isTriggered;

  const MpcPadEntity({
    required this.id,
    required this.index,
    required this.label,
    required this.sourceAudioUrl,
    required this.startSec,
    required this.endSec,
    this.pitchShiftSemitones = 0,
    this.isReversed = false,
    this.volume = 1.0,
    this.isMuted = false,
    this.isTriggered = false,
  });

  MpcPadEntity copyWith({
    int? pitchShiftSemitones,
    bool? isReversed,
    double? volume,
    bool? isMuted,
    bool? isTriggered,
  }) {
    return MpcPadEntity(
      id: id,
      index: index,
      label: label,
      sourceAudioUrl: sourceAudioUrl,
      startSec: startSec,
      endSec: endSec,
      pitchShiftSemitones: pitchShiftSemitones ?? this.pitchShiftSemitones,
      isReversed: isReversed ?? this.isReversed,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isTriggered: isTriggered ?? this.isTriggered,
    );
  }
}

class MpcSlicerState {
  final List<MpcPadEntity> pads;
  final int selectedPadIndex;
  final String sourceTitle;
  final int bpm;
  final double timeStretchRatio; // 0.5 to 2.0
  final bool isPlaying;
  final String? lastBouncedChopPath;

  const MpcSlicerState({
    required this.pads,
    this.selectedPadIndex = 0,
    this.sourceTitle = 'Mbira DzaVadzimu',
    this.bpm = 112,
    this.timeStretchRatio = 1.0,
    this.isPlaying = false,
    this.lastBouncedChopPath,
  });

  MpcPadEntity get selectedPad => pads[selectedPadIndex.clamp(0, pads.length - 1)];

  MpcSlicerState copyWith({
    List<MpcPadEntity>? pads,
    int? selectedPadIndex,
    String? sourceTitle,
    int? bpm,
    double? timeStretchRatio,
    bool? isPlaying,
    String? lastBouncedChopPath,
  }) {
    return MpcSlicerState(
      pads: pads ?? this.pads,
      selectedPadIndex: selectedPadIndex ?? this.selectedPadIndex,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      bpm: bpm ?? this.bpm,
      timeStretchRatio: timeStretchRatio ?? this.timeStretchRatio,
      isPlaying: isPlaying ?? this.isPlaying,
      lastBouncedChopPath: lastBouncedChopPath ?? this.lastBouncedChopPath,
    );
  }
}
```

### 1.3 `HeritageCrateProvider` & `MpcSlicerProvider`
**File:** `lib/features/studio/presentation/providers/heritage_crate_provider.dart`

```dart
class HeritageCrateState {
  final List<HeritageSampleEntity> allSamples;
  final HeritageCrateCategory activeCategory;
  final String searchQuery;
  final String? auditioningSampleId;

  const HeritageCrateState({
    required this.allSamples,
    this.activeCategory = HeritageCrateCategory.all,
    this.searchQuery = '',
    this.auditioningSampleId,
  });

  List<HeritageSampleEntity> get filteredSamples { ... }
}

class HeritageCrateNotifier extends StateNotifier<HeritageCrateState> {
  void setCategory(HeritageCrateCategory category);
  void setSearchQuery(String query);
  void toggleFavorite(String sampleId);
  void startAudition(String sampleId);
  void stopAudition();
}

class MpcSlicerNotifier extends StateNotifier<MpcSlicerState> {
  void sliceSample(HeritageSampleEntity sample);
  void selectPad(int index);
  void triggerPad(int index);
  void setPitchShift(int index, int semitones);
  void toggleReverse(int index);
  void setPadVolume(int index, double vol);
  void setTimeStretch(double ratio);
  Future<String> bounceChops();
}
```

---

## 2. Track B: Video Export & Direct Social Syndication

### 2.1 `VideoExportJob` & `VideoExportState`
**File:** `lib/features/social/domain/models/video_export_job.dart`

```dart
enum VideoExportResolution {
  vertical9x16('9:16 Kinetic Reel', 1080, 1920),
  square1x1('1:1 Cover Art Video', 1080, 1080);

  final String label;
  final int width;
  final int height;
  const VideoExportResolution(this.label, this.width, this.height);
}

enum SocialShareTarget {
  tiktok('TikTok', '🎵'),
  instagramReels('Instagram Reels', '📸'),
  youtubeShorts('YouTube Shorts', '▶️'),
  cameraRoll('Save to Gallery', '💾');

  final String label;
  final String emoji;
  const SocialShareTarget(this.label, this.emoji);
}

enum VideoExportStatus { idle, muxing, completed, failed }

class VideoExportJob {
  final String id;
  final String title;
  final String creatorHandle;
  final String genre;
  final String audioPath;
  final VideoExportResolution resolution;
  final int fps; // 30 or 60
  final bool includeHolographicWatermark;
  final double durationSec;

  const VideoExportJob({
    required this.id,
    required this.title,
    required this.creatorHandle,
    required this.genre,
    required this.audioPath,
    this.resolution = VideoExportResolution.vertical9x16,
    this.fps = 60,
    this.includeHolographicWatermark = true,
    this.durationSec = 15.0,
  });
}

class VideoExportState {
  final VideoExportJob? activeJob;
  final VideoExportStatus status;
  final double progress; // 0.0 to 1.0
  final String? outputPath;
  final String? errorMessage;
  final String? generatedCaption;
  final SocialShareTarget? lastSharedTarget;

  const VideoExportState({
    this.activeJob,
    this.status = VideoExportStatus.idle,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    this.generatedCaption,
    this.lastSharedTarget,
  });
}
```

### 2.2 `VideoExportNotifier` & `videoExportProvider`
**File:** `lib/features/social/presentation/providers/video_export_provider.dart`

```dart
class VideoExportNotifier extends StateNotifier<VideoExportState> {
  void prepareJob(VideoExportJob job);
  void toggleWatermark(bool enabled);
  void setResolution(VideoExportResolution resolution);
  void setFps(int fps);
  String generateViralCaption(String title, String creatorHandle, String genre);
  Future<String?> startMuxing();
  Future<bool> shareTo(SocialShareTarget target);
  void reset();
}
```

---

## 3. Presentation Widget Architecture

### Track A UI:
- **`CrateBrowserDeck`** (`lib/features/studio/presentation/widgets/crate_browser_deck.dart`):
  - Spinning vinyl disk badge with continuous rotation when auditioning.
  - Category selector chips (`All`, `Percussion`, `Plucked Strings`, etc.).
  - Search field matching name, instrument, or culture region.
  - Sample tile with play/pause audition button, waveform preview, and "✂ Chop in MPC" CTA.
- **`MpcSlicerDeck`** (`lib/features/studio/presentation/widgets/mpc_slicer_deck.dart`):
  - Top header displaying source sample title, BPM, and time-stretch slider (0.5× to 2.0×).
  - 4×2 grid of tactile MPC pads (`Key('mpc_pad_$index')`), displaying pad label, start time, pitch badge, and reverse badge.
  - Active pad control dock: semitone pitch slider (−12 to +12), reverse switch, pad volume slider.
  - Bottom action bar: "🎹 Send to Stem Mixer" (`Key('mpc_send_to_mixer')`) and "🎙️ Record into Studio" (`Key('mpc_send_to_studio')`).

### Track B UI:
- **`VideoExportModal`** (`lib/features/social/presentation/widgets/video_export_modal.dart`):
  - Preview thumbnail with animated watermark toggle.
  - Resolution selector chips (9:16 vs 1:1) and FPS selector chips (30 vs 60).
  - "Render Video" button (`Key('export_render_btn')`) triggering high-speed muxing with real-time linear progress indicator.
  - Auto-generated viral caption container with 1-tap "Copy" button.
  - **`SocialShareRail`**: 4 action buttons (`Key('share_tiktok_btn')`, `Key('share_instagram_btn')`, `Key('share_shorts_btn')`, `Key('share_gallery_btn')`).
