# Phase 38 Technical Design: Kinetic Posts Architecture & Non-Invasive Sonic Feed

**Document Version:** 1.0.0  
**Status:** Approved  

---

## 1. Domain Models & Data Structures

### 1.1 `KineticPostImageAttachment`
```dart
enum KineticPostAspectRatio {
  square1x1(1.0, '1:1 Square'),
  portrait4x5(4.0 / 5.0, '4:5 Portrait'),
  landscape16x9(16.0 / 9.0, '16:9 Wide');

  const KineticPostAspectRatio(this.ratio, this.label);
  final double ratio;
  final String label;
}

@immutable
class KineticPostImageAttachment {
  final String imageUrl;
  final bool isAiGeneratedVision;
  final String? visionPrompt;
  final KineticPostAspectRatio aspectRatio;

  const KineticPostImageAttachment({
    required this.imageUrl,
    this.isAiGeneratedVision = false,
    this.visionPrompt,
    this.aspectRatio = KineticPostAspectRatio.square1x1,
  });

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'isAiGeneratedVision': isAiGeneratedVision,
    if (visionPrompt != null) 'visionPrompt': visionPrompt,
    'aspectRatio': aspectRatio.name,
  };

  factory KineticPostImageAttachment.fromJson(Map<String, dynamic> json) =>
      KineticPostImageAttachment(
        imageUrl: json['imageUrl'] as String,
        isAiGeneratedVision: json['isAiGeneratedVision'] as bool? ?? false,
        visionPrompt: json['visionPrompt'] as String?,
        aspectRatio: KineticPostAspectRatio.values.firstWhere(
          (e) => e.name == json['aspectRatio'],
          orElse: () => KineticPostAspectRatio.square1x1,
        ),
      );
}
```

### 1.2 `KineticPostAudioAttachment`
```dart
enum KineticAudioSourceType {
  librarySong('Song'),
  beatListing('Beat'),
  voiceSignature('Voice DNA'),
  sketchpadGroove('Groove');

  const KineticAudioSourceType(this.label);
  final String label;
}

@immutable
class KineticPostAudioAttachment {
  final KineticAudioSourceType sourceType;
  final double clipStartSec;
  final double clipDurationSec;
  final String originalCreatorId;
  final String originalCreatorHandle;
  final bool allowSoundReuse;
  final bool allowRepost;

  const KineticPostAudioAttachment({
    this.sourceType = KineticAudioSourceType.librarySong,
    this.clipStartSec = 0.0,
    this.clipDurationSec = 30.0,
    required this.originalCreatorId,
    required this.originalCreatorHandle,
    this.allowSoundReuse = true,
    this.allowRepost = true,
  });

  Map<String, dynamic> toJson() => {
    'sourceType': sourceType.name,
    'clipStartSec': clipStartSec,
    'clipDurationSec': clipDurationSec,
    'originalCreatorId': originalCreatorId,
    'originalCreatorHandle': originalCreatorHandle,
    'allowSoundReuse': allowSoundReuse,
    'allowRepost': allowRepost,
  };

  factory KineticPostAudioAttachment.fromJson(Map<String, dynamic> json) =>
      KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.values.firstWhere(
          (e) => e.name == json['sourceType'],
          orElse: () => KineticAudioSourceType.librarySong,
        ),
        clipStartSec: (json['clipStartSec'] as num?)?.toDouble() ?? 0.0,
        clipDurationSec: (json['clipDurationSec'] as num?)?.toDouble() ?? 30.0,
        originalCreatorId: json['originalCreatorId'] as String? ?? '',
        originalCreatorHandle: json['originalCreatorHandle'] as String? ?? '',
        allowSoundReuse: json['allowSoundReuse'] as bool? ?? true,
        allowRepost: json['allowRepost'] as bool? ?? true,
      );
}
```

### 1.3 Media Validation Guard (`REQ-KPOST-NO-MP4`)
```dart
bool isAllowedKineticPostMedia(String pathOrMime) {
  final lower = pathOrMime.toLowerCase();
  // Reject video formats outright
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mkv') ||
      lower.startsWith('video/')) {
    return false;
  }
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.startsWith('image/');
}
```

---

## 2. Component Architecture

### 2.1 `KineticPostSonicPill`
- Embedded in `ExploreSocialPostCard`.
- Dynamic height:
  - Inside image container: `40dp` height with frosted glass (`BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))`).
  - Outside image (text-only post): `44dp` capsule with `AppColors.surfaceSecondary` background.
- Interactive handshake:
  - Tap play -> `ref.read(playerStateProvider.notifier).playTrack(...)` with `clipStartSec`.
  - Micro-equalizer animates when `playerState.currentTrack?.id == post.track.id && playerState.isPlaying`.

### 2.2 `KineticPostComposerBar`
- Mounted in `ExploreView` above feed list.
- User avatar, prompt placeholder, and quick action icons.
- Tap launches `CreateKineticPostSheet.show(context)`.

### 2.3 `CreateKineticPostSheet`
- Full-screen or 85% modal sheet.
- Caption input box.
- Visual selector with preset Vhunambi Vision artwork generator.
- Aspect ratio switcher buttons.
- 4-tab vault audio picker and duration trim pills (15s, 30s, 60s, Full).
- One-tap post creation dispatched to `explorePostsProvider`.

