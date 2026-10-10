# Phase 18 · Design — Social Creator Network & In-House Kinetic Reels Discovery

> **Phase:** 18  
> **Codename:** `social-creator-network`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client` & `apps/vhunambi_api`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Domain Models & Entities (Dart / Flutter)

### 1.1 `PublishedClip` Domain Entity
```dart
// lib/features/social/domain/models/published_clip.dart

import 'package:flutter/foundation.dart';
import '../../content_studio/domain/models/song_metadata_dna.dart';

@immutable
class PublishedClip {
  final String id;
  final String trackId;
  final String creatorId;
  final String creatorUsername;
  final String creatorDisplayName;
  final String? creatorAvatarUrl;
  final bool isCreatorVerified;
  
  final String title;
  final String caption;
  final List<String> tags;
  final String genre;
  final String audioUrl;
  final String coverUrl;
  
  /// The immutable Song DNA powering zero-video vector canvas playback.
  final SongMetadataDNA dna;
  
  final int playCount;
  final int likeCount;
  final int commentCount;
  final int remixCount;
  final bool isLikedByMe;
  final bool isSavedByMe;
  
  final DateTime publishedAt;

  const PublishedClip({
    required this.id,
    required this.trackId,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorDisplayName,
    this.creatorAvatarUrl,
    this.isCreatorVerified = false,
    required this.title,
    required this.caption,
    this.tags = const [],
    required this.genre,
    required this.audioUrl,
    required this.coverUrl,
    required this.dna,
    this.playCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.remixCount = 0,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    required this.publishedAt,
  });

  PublishedClip copyWith({
    int? playCount,
    int? likeCount,
    int? commentCount,
    int? remixCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
  }) {
    return PublishedClip(
      id: id,
      trackId: trackId,
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      creatorDisplayName: creatorDisplayName,
      creatorAvatarUrl: creatorAvatarUrl,
      isCreatorVerified: isCreatorVerified,
      title: title,
      caption: caption,
      tags: tags,
      genre: genre,
      audioUrl: audioUrl,
      coverUrl: coverUrl,
      dna: dna,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      remixCount: remixCount ?? this.remixCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      publishedAt: publishedAt,
    );
  }
}
```

---

## 2. Riverpod State Providers

### 2.1 `SocialFeedNotifier` & Provider
```dart
// lib/features/social/presentation/providers/social_feed_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/published_clip.dart';

class SocialFeedState {
  final List<PublishedClip> clips;
  final bool isLoading;
  final String? errorMessage;
  final int activeIndex;

  const SocialFeedState({
    this.clips = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeIndex = 0,
  });

  SocialFeedState copyWith({
    List<PublishedClip> clips,
    bool? isLoading,
    String? errorMessage,
    int? activeIndex,
  }) {
    return SocialFeedState(
      clips: clips ?? this.clips,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class SocialFeedNotifier extends StateNotifier<SocialFeedState> {
  SocialFeedNotifier() : super(const SocialFeedState()) {
    loadFeed();
  }

  Future<void> loadFeed() async { ... }
  void toggleLike(String clipId) { ... }
  void setActiveIndex(int index) { ... }
  void prependUserClip(PublishedClip newClip) {
    state = state.copyWith(clips: [newClip, ...state.clips]);
  }
}

final socialFeedProvider = StateNotifierProvider<SocialFeedNotifier, SocialFeedState>((ref) {
  return SocialFeedNotifier();
});
```

### 2.2 `CreatorClipsFamilyProvider`
```dart
// lib/features/social/presentation/providers/creator_clips_provider.dart

final creatorClipsFamilyProvider = StateNotifierProvider.family<CreatorClipsNotifier, List<PublishedClip>, String>((ref, creatorId) {
  return CreatorClipsNotifier(creatorId: creatorId);
});
```

---

## 3. UI Component Hierarchy & Architecture

```
ArtistProfileView (Scaffold)
 └── NestedScrollView
      ├── SliverPersistentHeader (ProfileBannerHeader + Stats + Follow/Tip Actions)
      ├── SliverPersistentHeader (TabBar: 🎬 Clips | 🎵 Music | 🛍️ Beats)
      └── TabBarView
           ├── Tab 1: CreatorReelsGrid (SliverGrid: 3-column / 4-column)
           │    └── CreatorReelThumbnailCard (9:16 AspectRatio)
           │         ├── Cover Artwork (CachedNetworkImage)
           │         ├── Play count pill (▶ 24.5K)
           │         └── Tap Handler -> KineticReelsModal.show(context, initialClipId)
           ├── Tab 2: DiscographyShelf (Top Songs + Albums)
           └── Tab 3: BeatsAndBioTab (Commercial Licenses, Stem Packs, Top Supporters)

KineticReelsModal (Full-Screen Vertical Feed)
 └── PageView.builder (scrollDirection: Axis.vertical)
      └── KineticReelPageItem
           ├── Background Ambient Blur
           ├── KineticPreviewCanvas (Synchronized 60/120fps Karaoke & Particles)
           ├── Tap-to-Pause Layer (Spring Play/Pause Indicator)
           ├── Bottom Overlay (Title, Creator Name, Caption, Tags)
           ├── Bottom Sound Pill ("🎵 Song Title • Original Sound [Remix in Studio]")
           └── Right Social Action Rail:
                ├── Creator Avatar (+ Follow badge)
                ├── ❤️ Like Button (Count)
                ├── 💬 Comments Button
                ├── ⚡ Tip Button
                └── ↗️ Share Clip Button
```

---

## 4. In-House Publishing Dialog (`PublishClipModal`)

```
PublishClipModal
 ├── Header ("Publish to Vhunambi Profile", Close Button)
 ├── Row:
 │    ├── 9:16 Miniature Thumbnail (with current canvas state)
 │    └── Form Fields:
 │         ├── TextField ("What's this song about?", max 140 chars)
 │         ├── Tag Suggestions Pills (#Amapiano, #Tshivenḓa, #AfroHouse, #Vocal)
 │         └── Visibility Selector (Public / Followers Only)
 └── Actions:
      ├── Cancel Button
      └── "🚀 Publish Reel" (ElevatedButton, AppColors.brandPrimary)
```

---

## 5. Backend REST API Contract (`apps/vhunambi_api`)

### 5.1 `POST /api/social/publish`
- **Request Body**:
```json
{
  "trackId": "track_amapiano_101",
  "title": "Ndo Mufuna Matibe",
  "caption": "New late-night piano vibe featuring indigenous live percussion! 🎹🔥",
  "tags": ["Amapiano", "Tshivenḓa", "DeepSoul"],
  "dna": {
    "genre": "Amapiano",
    "bpm": 113,
    "mood": "Uplifting",
    "paletteId": "sunsetGold",
    "typographyPreset": "karaokeBounce",
    "timestamps": [...]
  }
}
```
- **Response**: `201 Created`
```json
{
  "clipId": "clip_pub_9841",
  "shareUrl": "https://vhunambi.com/@makhadzi/reels/clip_pub_9841",
  "publishedAt": "2026-10-10T22:00:00Z"
}
```

### 5.2 `GET /api/social/feed?cursor=...&limit=20`
- **Response**: `200 OK`
```json
{
  "clips": [ ... ],
  "nextCursor": "cursor_ey98..."
}
```

### 5.3 `POST /api/social/clips/:id/like`
- **Response**: `200 OK` (`{ "liked": true, "likeCount": 842 }`)

---

## 6. Token Bindings & Invariant Checklist

- **Canvases**: `AppColors.surfaceCanvas`, `AppColors.surfaceElevated`.
- **Accents**: `AppColors.brandPrimary` (CTA & Play progress), `AppColors.brandAccent` (Likes), `AppColors.coinGold` (Tips).
- **Radii**: `AppRadius.cardBorder` (12px), `AppRadius.modalBorder` (20px), `AppRadius.pillBorder` (999px).
- **Motion**: Strictly `HYDRATION_SAFE_VARIANTS` from `lib/motion-config.ts`.
