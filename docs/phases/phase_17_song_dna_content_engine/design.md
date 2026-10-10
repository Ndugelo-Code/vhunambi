# Phase 17 · Design — Song Metadata DNA & Lyric Video Content Engine

> **Phase:** 17  
> **Codename:** `song-dna-content-dock`  
> **Parent Blueprint:** `docs/phases/phase_17_song_dna_content_engine/blueprint.md`  
> **Parent Requirements:** `docs/phases/phase_17_song_dna_content_engine/requirements.md`  
> **Standard:** Production Dart 3.x / Flutter Riverpod 2.x & TypeScript Node.js / Hono  

---

## 1. Package Layout & File Locations

### 1.1 Flutter Client (`apps/vhunambi_client`)
```
lib/features/content_studio/
├── domain/
│   ├── models/
│   │   ├── song_metadata_dna.dart       # Immutable Song DNA domain entity
│   │   ├── lyric_word_timestamp.dart    # Word-level timestamp contract
│   │   └── content_studio_preset.dart   # Typography, duration & effects enums
│   └── services/
│       └── i_video_export_service.dart  # Abstract export service contract
├── data/
│   ├── services/
│   │   ├── local_video_export_service.dart  # Hardware-accelerated local FFmpeg muxer
│   │   └── cloud_video_export_service.dart  # Fallback HTTP export service
│   └── repositories/
│       └── content_studio_repository.dart   # Hive cache for video drafts & DNA
└── presentation/
    ├── providers/
    │   └── content_studio_provider.dart # ContentStudioState & ContentStudioNotifier
    ├── views/
    │   └── content_studio_dock_view.dart# Responsive 9:16 cockpit (/track/:id/content)
    └── widgets/
        ├── kinetic_preview_canvas.dart  # 60 FPS CustomPainter & animated lyric overlay
        ├── typography_preset_picker.dart# Kinetic Bounce, Luminous Glow, Minimal, Calligraphy
        ├── duration_trim_scrubber.dart  # 15s Hook / 30s Reel / Full Track range scrubber
        ├── atmospheric_effects_deck.dart# Film grain, Ken Burns, audio-reactive pulses
        └── export_action_sheet.dart     # Native share & download dialog
```

### 1.2 Backend Gateway (`apps/vhunambi_api`)
```
src/modules/
├── dna/
│   ├── dna_compiler.ts                  # Compiles wizard inputs into SongMetadataDNA
│   └── dna_types.ts                     # TypeScript interfaces matching Dart domain
├── vision/
│   ├── comfyui_adapter.ts               # RunPod Serverless ComfyUI 9:16 dispatch
│   └── prompt_synthesizer.ts            # LLM middleware converting DNA to SDXL/FLUX prompt
└── video/
    ├── alignment_bridge.ts              # stable-ts Whisper JSON alignment parser
    └── export_worker.ts                 # Web fallback cloud rendering queue
```

---

## 2. Dart Domain Models (`apps/vhunambi_client`)

### 2.1 `song_metadata_dna.dart`
```dart
import 'package:flutter/foundation.dart';
import 'lyric_word_timestamp.dart';

@immutable
class SongMetadataDna {
  final String id;
  final String version;
  final String title;
  final String genre;
  final String language;
  final CulturalContextDna? culturalContext;
  final MusicalDna musical;
  final VocalsDna vocals;
  final VisualThemeDna visualTheme;
  final List<LyricWordTimestamp> alignment;

  const SongMetadataDna({
    required this.id,
    this.version = '1.0',
    required this.title,
    required this.genre,
    required this.language,
    this.culturalContext,
    required this.musical,
    required this.vocals,
    required this.visualTheme,
    this.alignment = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'genre': genre,
        'language': language,
        if (culturalContext != null) 'culturalContext': culturalContext!.toJson(),
        'musical': musical.toJson(),
        'vocals': vocals.toJson(),
        'visualTheme': visualTheme.toJson(),
        'alignment': alignment.map((w) => w.toJson()).toList(),
      };

  factory SongMetadataDna.fromJson(Map<String, dynamic> json) {
    return SongMetadataDna(
      id: json['id'] as String,
      version: json['version'] as String? ?? '1.0',
      title: json['title'] as String? ?? 'Untitled',
      genre: json['genre'] as String? ?? 'Amapiano',
      language: json['language'] as String? ?? 'Tshivenḓa',
      culturalContext: json['culturalContext'] != null
          ? CulturalContextDna.fromJson(json['culturalContext'] as Map<String, dynamic>)
          : null,
      musical: MusicalDna.fromJson(json['musical'] as Map<String, dynamic>),
      vocals: VocalsDna.fromJson(json['vocals'] as Map<String, dynamic>),
      visualTheme: VisualThemeDna.fromJson(json['visualTheme'] as Map<String, dynamic>),
      alignment: (json['alignment'] as List<dynamic>?)
              ?.map((w) => LyricWordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

@immutable
class CulturalContextDna {
  final String region;
  final List<String> idioms;
  final String phoneticGuidelines;

  const CulturalContextDna({
    required this.region,
    this.idioms = const [],
    this.phoneticGuidelines = '',
  });

  Map<String, dynamic> toJson() => {
        'region': region,
        'idioms': idioms,
        'phoneticGuidelines': phoneticGuidelines,
      };

  factory CulturalContextDna.fromJson(Map<String, dynamic> json) =>
      CulturalContextDna(
        region: json['region'] as String? ?? 'Limpopo, South Africa',
        idioms: (json['idioms'] as List<dynamic>?)?.cast<String>() ?? const [],
        phoneticGuidelines: json['phoneticGuidelines'] as String? ?? '',
      );
}

@immutable
class MusicalDna {
  final int bpm;
  final String key;
  final String energyBracket; // 'soft', 'mid', 'intense'
  final int durationSec;

  const MusicalDna({
    required this.bpm,
    required this.key,
    required this.energyBracket,
    required this.durationSec,
  });

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'key': key,
        'energyBracket': energyBracket,
        'durationSec': durationSec,
      };

  factory MusicalDna.fromJson(Map<String, dynamic> json) => MusicalDna(
        bpm: json['bpm'] as int? ?? 112,
        key: json['key'] as String? ?? 'F# Minor',
        energyBracket: json['energyBracket'] as String? ?? 'mid',
        durationSec: json['durationSec'] as int? ?? 180,
      );
}

@immutable
class VocalsDna {
  final String deliveryMode; // 'melodic', 'rap', 'spokenWord', 'choir'
  final String gender;       // 'male', 'female', 'duet'
  final String energy;       // 'soft', 'mid', 'intense'
  final List<Map<String, dynamic>> loras;

  const VocalsDna({
    required this.deliveryMode,
    required this.gender,
    required this.energy,
    this.loras = const [],
  });

  Map<String, dynamic> toJson() => {
        'deliveryMode': deliveryMode,
        'gender': gender,
        'energy': energy,
        'loras': loras,
      };

  factory VocalsDna.fromJson(Map<String, dynamic> json) => VocalsDna(
        deliveryMode: json['deliveryMode'] as String? ?? 'melodic',
        gender: json['gender'] as String? ?? 'male',
        energy: json['energy'] as String? ?? 'mid',
        loras: (json['loras'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [],
      );
}

@immutable
class VisualThemeDna {
  final String mood;
  final String comfyPrompt;
  final String negativePrompt;
  final int seed;
  final String aspectRatio; // '9:16'

  const VisualThemeDna({
    required this.mood,
    required this.comfyPrompt,
    this.negativePrompt = 'blurry, low quality, watermark, text, signature',
    required this.seed,
    this.aspectRatio = '9:16',
  });

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'comfyPrompt': comfyPrompt,
        'negativePrompt': negativePrompt,
        'seed': seed,
        'aspectRatio': aspectRatio,
      };

  factory VisualThemeDna.fromJson(Map<String, dynamic> json) => VisualThemeDna(
        mood: json['mood'] as String? ?? 'Cinematic',
        comfyPrompt: json['comfyPrompt'] as String? ?? '',
        negativePrompt: json['negativePrompt'] as String? ?? 'blurry, low quality, text',
        seed: json['seed'] as int? ?? 42,
        aspectRatio: json['aspectRatio'] as String? ?? '9:16',
      );
}
```

### 2.2 `lyric_word_timestamp.dart`
```dart
import 'package:flutter/foundation.dart';

@immutable
class LyricWordTimestamp {
  final String word;
  final double start;
  final double end;
  final int stanzaIndex;

  const LyricWordTimestamp({
    required this.word,
    required this.start,
    required this.end,
    this.stanzaIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'start': start,
        'end': end,
        'stanzaIndex': stanzaIndex,
      };

  factory LyricWordTimestamp.fromJson(Map<String, dynamic> json) =>
      LyricWordTimestamp(
        word: json['word'] as String? ?? '',
        start: (json['start'] as num?)?.toDouble() ?? 0.0,
        end: (json['end'] as num?)?.toDouble() ?? 0.0,
        stanzaIndex: json['stanzaIndex'] as int? ?? 0,
      );
}
```

### 2.3 `content_studio_preset.dart`
```dart
enum LyricTypographyPreset {
  kineticBounce,
  luminousGlow,
  minimalSubtitle,
  bantuCalligraphy;

  String get label => switch (this) {
        LyricTypographyPreset.kineticBounce => 'Kinetic Bounce',
        LyricTypographyPreset.luminousGlow => 'Luminous Glow',
        LyricTypographyPreset.minimalSubtitle => 'Minimal Subtitle',
        LyricTypographyPreset.bantuCalligraphy => 'Bantu Calligraphy',
      };

  String get description => switch (this) {
        LyricTypographyPreset.kineticBounce => 'High-energy 1.15x word pop with Brand Amber glow',
        LyricTypographyPreset.luminousGlow => 'Radial atmospheric blur glow in title case',
        LyricTypographyPreset.minimalSubtitle => 'Crisp lower-third glass banner with karaoke sweep',
        LyricTypographyPreset.bantuCalligraphy => 'Stylized serif headline with dynamic underline',
      };
}

enum DurationPreset {
  hook15s,
  reel30s,
  fullTrack;

  int get targetSeconds => switch (this) {
        DurationPreset.hook15s => 15,
        DurationPreset.reel30s => 30,
        DurationPreset.fullTrack => 180,
      };

  String get label => switch (this) {
        DurationPreset.hook15s => '15s Hook',
        DurationPreset.reel30s => '30s Reel',
        DurationPreset.fullTrack => 'Full Track',
      };
}

class AtmosphericEffects {
  final bool filmGrain;
  final bool bassPulse;
  final bool kenBurnsMotion;

  const AtmosphericEffects({
    this.filmGrain = true,
    this.bassPulse = true,
    this.kenBurnsMotion = true,
  });

  AtmosphericEffects copyWith({
    bool? filmGrain,
    bool? bassPulse,
    bool? kenBurnsMotion,
  }) =>
      AtmosphericEffects(
        filmGrain: filmGrain ?? this.filmGrain,
        bassPulse: bassPulse ?? this.bassPulse,
        kenBurnsMotion: kenBurnsMotion ?? this.kenBurnsMotion,
      );
}
```

---

## 3. Riverpod State Notifier (`content_studio_provider.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/song_metadata_dna.dart';
import '../domain/models/content_studio_preset.dart';
import '../domain/models/lyric_word_timestamp.dart';
import '../domain/services/i_video_export_service.dart';

class ContentStudioState {
  final SongMetadataDna? dna;
  final String? audioUrl;
  final String? coverArtUrl;
  final List<LyricWordTimestamp> words;
  final LyricTypographyPreset typographyPreset;
  final DurationPreset durationPreset;
  final double startSeconds;
  final double endSeconds;
  final AtmosphericEffects effects;
  final bool isPlaying;
  final double playbackPositionSec;
  final bool isExporting;
  final double exportProgress;
  final String? exportedFilePath;
  final String? errorMessage;

  const ContentStudioState({
    this.dna,
    this.audioUrl,
    this.coverArtUrl,
    this.words = const [],
    this.typographyPreset = LyricTypographyPreset.kineticBounce,
    this.durationPreset = DurationPreset.reel30s,
    this.startSeconds = 0.0,
    this.endSeconds = 30.0,
    this.effects = const AtmosphericEffects(),
    this.isPlaying = false,
    this.playbackPositionSec = 0.0,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportedFilePath,
    this.errorMessage,
  });

  ContentStudioState copyWith({
    SongMetadataDna? dna,
    String? audioUrl,
    String? coverArtUrl,
    List<LyricWordTimestamp>? words,
    LyricTypographyPreset? typographyPreset,
    DurationPreset? durationPreset,
    double? startSeconds,
    double? endSeconds,
    AtmosphericEffects? effects,
    bool? isPlaying,
    double? playbackPositionSec,
    bool? isExporting,
    double? exportProgress,
    String? exportedFilePath,
    String? errorMessage,
  }) {
    return ContentStudioState(
      dna: dna ?? this.dna,
      audioUrl: audioUrl ?? this.audioUrl,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      words: words ?? this.words,
      typographyPreset: typographyPreset ?? this.typographyPreset,
      durationPreset: durationPreset ?? this.durationPreset,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      effects: effects ?? this.effects,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPositionSec: playbackPositionSec ?? this.playbackPositionSec,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      errorMessage: errorMessage,
    );
  }
}

class ContentStudioNotifier extends StateNotifier<ContentStudioState> {
  final IVideoExportService _exportService;

  ContentStudioNotifier(this._exportService) : super(const ContentStudioState());

  void initializeWithDna({
    required SongMetadataDna dna,
    required String audioUrl,
    required String coverArtUrl,
  }) {
    state = state.copyWith(
      dna: dna,
      audioUrl: audioUrl,
      coverArtUrl: coverArtUrl,
      words: dna.alignment,
      startSeconds: 0.0,
      endSeconds: dna.musical.durationSec > 30 ? 30.0 : dna.musical.durationSec.toDouble(),
    );
  }

  void setPreset(LyricTypographyPreset preset) {
    state = state.copyWith(typographyPreset: preset);
  }

  void setDurationPreset(DurationPreset preset) {
    final maxSec = state.dna?.musical.durationSec.toDouble() ?? 180.0;
    final target = preset.targetSeconds.toDouble();
    final newEnd = (state.startSeconds + target) > maxSec ? maxSec : state.startSeconds + target;
    state = state.copyWith(durationPreset: preset, endSeconds: newEnd);
  }

  void setTrimBounds(double start, double end) {
    state = state.copyWith(startSeconds: start, endSeconds: end);
  }

  void toggleEffect({bool? filmGrain, bool? bassPulse, bool? kenBurns}) {
    state = state.copyWith(
      effects: state.effects.copyWith(
        filmGrain: filmGrain,
        bassPulse: bassPulse,
        kenBurnsMotion: kenBurns,
      ),
    );
  }

  void updatePlaybackPosition(double sec) {
    state = state.copyWith(playbackPositionSec: sec);
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  Future<void> exportVideo() async {
    if (state.isExporting) return;
    state = state.copyWith(isExporting: true, exportProgress: 0.0, errorMessage: null);

    try {
      final path = await _exportService.exportLyricVideo(
        audioUrl: state.audioUrl!,
        coverArtUrl: state.coverArtUrl!,
        words: state.words,
        startSec: state.startSeconds,
        endSec: state.endSeconds,
        preset: state.typographyPreset,
        effects: state.effects,
        onProgress: (progress) {
          state = state.copyWith(exportProgress: progress);
        },
      );
      state = state.copyWith(isExporting: false, exportProgress: 1.0, exportedFilePath: path);
    } catch (e) {
      state = state.copyWith(isExporting: false, errorMessage: e.toString());
    }
  }
}
```

---

## 4. 60 FPS Real-Time Kinetic Canvas (`kinetic_preview_canvas.dart`)

The kinetic preview uses Flutter's `CustomPainter` to layer:
1. **Background Layer:** 9:16 vertical cover image with a matrix transform simulating continuous Ken Burns zoom drift ($1.00 \times \to 1.05 \times$).
2. **Atmosphere Layer:** Canvas noise grain shader overlay + radial bass vignette.
3. **Active Word Karaoke Subtitles:**
   - Active word highlighted in `AppColors.brandPrimary` (`#FFB300`).
   - Inactive words rendered in semi-transparent white (`rgba(255, 255, 255, 0.75)`).
   - Word transition interpolation (smooth elastic scale bounce).
4. **Waveform Layer:** Bottom audio-reactive equalizer lines.

---

## 5. Backend Gateway Components (`apps/vhunambi_api`)

### 5.1 ComfyUI 9:16 Adapter (`comfyui_adapter.ts`)
```typescript
import { env } from '../../config/env.js';

export interface ComfyUIJobResult {
  jobId: string;
  outputImageUrl?: string;
}

export async function dispatchComfyUIVisionJob(
  promptText: string,
  seed: number = Math.floor(Math.random() * 1000000000),
): Promise<ComfyUIJobResult> {
  const payload = {
    client_id: 'vhunambi_vision',
    prompt: {
      '3': {
        inputs: { ckpt_name: 'sd_xl_base_1.0.safetensors' },
        class_type: 'CheckpointLoaderSimple',
      },
      '6': {
        inputs: {
          text: promptText,
          clip: ['3', 1],
        },
        class_type: 'CLIPTextEncode',
      },
      '7': {
        inputs: {
          text: 'blurry, low quality, watermark, text, signature, bad anatomy',
          clip: ['3', 1],
        },
        class_type: 'CLIPTextEncode',
      },
      '5': {
        // Native vertical 9:16 aspect ratio
        inputs: { width: 768, height: 1344, batch_size: 1 },
        class_type: 'EmptyLatentImage',
      },
      '10': {
        inputs: {
          seed,
          steps: 25,
          cfg: 7.0,
          sampler_name: 'euler',
          scheduler: 'normal',
          denoise: 1.0,
          model: ['3', 0],
          positive: ['6', 0],
          negative: ['7', 0],
          latent_image: ['5', 0],
        },
        class_type: 'KSampler',
      },
      '12': {
        inputs: { samples: ['10', 0], vae: ['3', 2] },
        class_type: 'VAEDecode',
      },
      '15': {
        inputs: { filename_prefix: 'vhunambi_9_16_art', images: ['12', 0] },
        class_type: 'SaveImage',
      },
    },
  };

  const response = await fetch(`${env.RUNPOD_COMFYUI_URL}/prompt`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const data = (await response.json()) as { prompt_id: string };
  return { jobId: data.prompt_id };
}
```
