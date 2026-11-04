# Phase 44 Blueprint: Frontend Video Defect Eradication, Android FS Crash Fix & Edge Outbox

## 1. Executive Summary

Phase 44 addresses and permanently eliminates the seven critical defects documented during the physical device walkthrough (`SVID_20261103_171715_1.mp4`) running on Android hardware (`EPHUT20917014649`), while establishing the client-side **Offline-First Mutation Outbox (`SyncOutboxService`)**. 

This phase represents the crucial bridge between device-level runtime stability (eliminating operating system filesystem permissions traps and visual theme inversions) and resilient edge-to-cloud synchronization. By hardening the Flutter client against mobile OS sandbox constraints and decoupling UI actions from immediate network connectivity, Vhunambi guarantees uninterrupted African music creation even under zero-connectivity field conditions.

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                           VHUNAMBI CLIENT ARCHITECTURE                            │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  [ UI Layer: Cinema Dark Lock & Contrast Harmony ]                                 │
│  ┌───────────────────────┐ ┌───────────────────────┐ ┌─────────────────────────┐  │
│  │   KineticReelsModal   │ │ CreateKineticPostSheet│ │ ProfileBannerHeader     │  │
│  │ (Dark Cinema Overlay) │ │ (Vision Procedural)   │ │ (Light/Dark TextPrimary)│  │
│  └───────────┬───────────┘ └───────────┬───────────┘ └────────────┬────────────┘  │
│              │                         │                          │               │
│  [ Orchestration & Lifecycle Guardians ]                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  modalSheetOpenCountProvider (Suppresses Mini-Player pill during modals)     │  │
│  │  PlayerNotifier (Suppresses Mini-Player on boot when track == 'Unknown')    │  │
│  └─────────────────────────────────────┬───────────────────────────────────────┘  │
│                                        │                                          │
│  [ Storage & Audio Bouncing Subsystem ]                                           │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  StemMixBounceService / OpenVerseRemixCockpitSheet                          │  │
│  │  Path Resolver: Directory.systemTemp.path / RAM Base64 Fallback (No / trap) │  │
│  └─────────────────────────────────────┬───────────────────────────────────────┘  │
│                                        │                                          │
│  [ Edge-First Mutation Outbox ]        │                                          │
│  ┌─────────────────────────────────────▼───────────────────────────────────────┐  │
│  │  SyncOutboxService (Hive Box: vhunambi_sync_outbox_box)                    │  │
│  │  Optimistic Riverpod Mutations ──► FIFO Queue ──► POST /api/sync/mutations │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Forensic Defect Audit Matrix (`SVID_20261103_171715_1.mp4`)

Every issue identified in the physical device recording has been analyzed to its exact source line, OS failure code, and user experience impact:

| Timestamp | Severity | Defect Caught on Screen | Root Cause & Failure Mechanism | Technical Remedy | Target Source Files |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **02:58–03:09** | **P0 Blocker** | Red snackbar crash when publishing Open-Verse Remix: `Failed to bounce mixdown: FileSystemException: Cannot open file, path = 'remix_open_verse_...wav' (OS Error: Read-only file system, errno = 30)` | `OpenVerseRemixCockpitSheet` passed a bare relative filename (`remix_open_verse_${ts}.wav`) to `StemMixBounceService.bounceMixToFile()`. On Linux/Android environments, relative paths resolve against the root directory `/`, which is mounted strictly read-only. | 1. Resolve path within `Directory.systemTemp.path` (or app documents path).<br>2. Wrap disk I/O in defensive `try/catch(FileSystemException)`.<br>3. Automatically fallback to in-memory `Uint8List` synthesized WAV with `data:audio/wav;base64,...` URI. | `open_verse_remix_cockpit_sheet.dart`<br>`stem_mix_bounce_service.dart` |
| **03:38–04:42** | **P0 Blocker** | Invisible black-on-black action rail in `KineticReelsModal` under Light Mode: Like, Comment, Share, and Translate icons become dark charcoal on top of the black video canvas. Top bar flashes stark white at 04:40. | `KineticReelsModal` queried `AppColors.textPrimaryOf(context)` and `AppColors.surfaceElevatedOf(context)`. When the app is in Light Mode, `textPrimaryOf` evaluates to `#121216` (charcoal), rendering invisible against the dark cinema background. | 1. Wrap the entire `KineticReelsModal` widget tree in `Theme(data: AppTheme.darkTheme)`.<br>2. Explicitly bind all right-rail action icons and top bar controls to `AppColors.darkTextPrimary` (`#FFFFFF`) with `BoxShadow(blurRadius: 4, color: Colors.black54)`. | `kinetic_reels_modal.dart` |
| **00:00–00:08** | **P1 Major** | Floating Mini-Player Pill renders `"Unknown - Unknown"` on initial boot and floats awkwardly over modal bottom sheets. | 1. `mini_player_host.dart` had no title emptiness or `'Unknown'` track suppression check.<br>2. Modal bottom sheets did not signal the mini-player host, leaving the pill floating over form inputs and CTA buttons. | 1. Enhance `MiniPlayerHost._shouldHide()` to evaluate `currentTrack == null \|\| currentTrack.title.trim().isEmpty \|\| currentTrack.title.trim() == 'Unknown'`.<br>2. Introduce `modalSheetOpenCountProvider` incremented when modal sheets open and decremented on dispose. | `mini_player_host.dart`<br>`navigation_providers.dart` |
| **00:12–00:22** | **P1 Major** | Broken image placeholder in `CreateKineticPostSheet` 80x80 preview thumbnail; audio attachment dropdown does not switch when selecting Song, Beat, Voice DNA, or Groove tabs. | 1. Thumbnail used `Image.network` with no fallback for local file paths or procedural `vision://` URIs.<br>2. Dropdown items were hardcoded to a static track list regardless of active media type tab. | 1. Replace broken thumbnail with `_buildProceduralThumbnail()` rendering algorithmic visual gradients and icons.<br>2. Dynamically bind dropdown to `libraryTracksProvider` (Songs), `beatsProvider` (Beats), `soundSignatureProvider` (Voice DNA), and `melodySketchpadProvider` (Grooves). | `create_kinetic_post_sheet.dart` |
| **00:24–00:55** | **P1 Major** | Post author attribution defaults to generic placeholder instead of logged-in creator profile; self-follow button appears on user's own posts; `Co-Sign (x/25)` badge is clipped in bottom row. | 1. Post creation did not read from `ownerProfileProvider`.<br>2. `ExploreSocialPostCard` unconditionally showed the `[ + Follow ]` button.<br>3. Six interactive buttons jammed into bottom row caused overflow on small screens. | 1. Inject `ownerProfileProvider` into `CreateKineticPostSheet` so posts inherit `@cern` identity.<br>2. Check `post.creatorHandle == owner.handle`: hide follow button or render `'Your Post'` chip.<br>3. Move `🔥 Co-Sign (x/25)` pill into secondary badge row below caption. | `create_kinetic_post_sheet.dart`<br>`explore_social_post_card.dart` |
| **01:34–01:44 & 04:09–04:13** | **P1 Major** | Share/Report icons in `ProfileBannerHeader` invisible in Light Mode; tapping Clips tab on `@sigwa` displays "No clips found". | 1. Action icon buttons used fixed light colors without theme adaptation.<br>2. `socialFeedProvider` did not seed any kinetic reels for creator handle `creator_sigwa`. | 1. Bind `ProfileBannerHeader` action icons to `AppColors.textPrimaryOf(context)`.<br>2. Seed at least one valid 9:16 kinetic reel for `creator_sigwa` in mock feed state. | `profile_banner_header.dart`<br>`social_feed_provider.dart` |
| **04:45** | **P1 Minor** | `CatalogFilterBar` uses raw emojis (`🎵`, `🥁`, `🎤`, `✨`) violating STD-UIUX-001; orphaned dead files clutter the project codebase. | 1. Raw emoji strings were used in category chips.<br>2. Five deprecated files remained in directory tree after UI migrations. | 1. Migrate chips to Phosphor vector icons (`PhosphorIconsRegular.musicNotes`, etc.).<br>2. Safely purge 5 dead files: `explore_header_section.dart`, `creator_card.dart`, `genre_radio_tile.dart`, `fluid_deck_switcher.dart`, `fake_stem_download_service.dart`. | `catalog_filter_bar.dart`<br>(File System Deletions) |

---

## 3. Cross-Layer Synergy with Phase 45 (Backend SQLite Persistence)

Phase 44 (Edge Outbox) and Phase 45 (SQLite WAL Engine) form a cohesive, decoupled transaction boundary:

```
[Flutter Client: Phase 44]                             [Backend API: Phase 45]
┌────────────────────────────┐                         ┌────────────────────────────┐
│ User Action (Like/Post/Buy)│                         │                            │
└─────────────┬──────────────┘                         │                            │
              ▼                                        │                            │
┌────────────────────────────┐                         │                            │
│ Optimistic Riverpod Update │                         │                            │
└─────────────┬──────────────┘                         │                            │
              ▼                                        │                            │
┌────────────────────────────┐                         │                            │
│ SyncOutboxService.enqueue()│                         │                            │
│ (Hive Box: Durable Outbox) │                         │                            │
└─────────────┬──────────────┘                         │                            │
              │                                        │                            │
              │ POST /api/sync/mutations               │                            │
              │ Payload: [{ idempotencyKey, ... }]     │                            │
              ├───────────────────────────────────────►│ Idempotency Deduplication  │
              │                                        │ PRAGMA journal_mode=WAL    │
              │ 200 OK: { applied: [keys], seq: 104 }  │ BEGIN TRANSACTION          │
              │◄───────────────────────────────────────┤ COMMIT; seq = seq + 1      │
              ▼                                        └────────────────────────────┘
┌────────────────────────────┐                                        │
│ Mark Outbox Records Synced │                                        │
└────────────────────────────┘                                        │
              │                                                       │
              │ GET /api/sync/delta?since=103                         │
              │ Header: If-None-Match: "cursor-104"                   │
              ├───────────────────────────────────────────────────────┤
              │ 304 Not Modified (or 200 with new server events)      │
              │◄──────────────────────────────────────────────────────┘
```

1. **Deterministic Idempotency**: Every client mutation generates a UUIDv4 `idempotencyKey`. If a network interruption occurs during transmission, retrying the mutation will never result in duplicate database records or double-billing.
2. **Monotonic Sequence Tracking**: The backend assigns an incrementing `seq` counter to each committed mutation log. The client persists the latest acknowledged `serverCursorSeq`, enabling delta synchronization using lightweight `since=<seq>` queries.
3. **HTTP 304 Cache Acceleration**: The delta endpoint generates an `ETag: "cursor-<latestSeq>"`. When no new mutations have occurred, the server responds instantly with `304 Not Modified`, saving battery and mobile bandwidth.

---

## 4. Invariants & Non-Negotiable Engineering Rules

1. **Zero Raw Emojis (STD-UIUX-001)**: All chips, buttons, badges, and headers must strictly use `PhosphorIcons` vector icons. Raw Unicode emojis are strictly forbidden.
2. **Cinema Dark Invariant**: Any full-screen media surface (`KineticReelsModal`, video canvases, DAW transport overlays) must enforce `Theme(data: AppTheme.darkTheme)` and use `#FFFFFF` text/icon tokens with subtle dropshadows. Under no circumstances may light-mode color tokens be applied over a dark video canvas.
3. **No Unchecked Root Filesystem Access**: Every file creation or write operation in Flutter must explicitly prepend `(await getTemporaryDirectory()).path` or `(await getApplicationDocumentsDirectory()).path`. Bare filenames are strictly forbidden.
4. **Modal Mini-Player Non-Interference**: The floating mini-player must never overlap, obscure, or collide with modal bottom sheets, dialogs, or full-screen overlays.
5. **No Polling**: All synchronization and state reactivity must be driven by explicit user events, push triggers, or Riverpod lifecycle subscriptions. Continuous polling loops are prohibited.
