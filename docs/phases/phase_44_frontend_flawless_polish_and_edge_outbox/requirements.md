# Requirements Document: Phase 44 Frontend Video Defect Eradication & Edge Outbox

## Introduction

Phase 44 provides a comprehensive stabilization pass for the Vhunambi Flutter client (`apps/vhunambi_client`), resolving seven critical defects identified during high-stress testing on physical Android hardware (`EPHUT20917014649`, recorded in `SVID_20261103_171715_1.mp4`). In addition to eliminating runtime filesystem exceptions and visual contrast defects, this phase introduces the client-side **Offline-First Mutation Outbox (`SyncOutboxService`)** to guarantee data durability and offline resilience for all creator interactions.

---

## Glossary

- **Stem_Mix_Bounce_Service**: Audio engine service responsible for summing multitrack stem buffers (Vocals, Drums, Bass, Melodic) into a unified master WAV file.
- **Open_Verse_Remix_Cockpit_Sheet**: Modal bottom sheet where users record vocal verses over open instrumental stems, preview the summed mixdown, and publish to the social feed.
- **Read_Only_FS_Trap**: Linux/Android operating system constraint where relative paths lacking a preceding directory path resolve against root (`/`), causing `FileSystemException: Cannot open file (OS Error: Read-only file system, errno = 30)`.
- **System_Temp_Directory**: Platform-specific sandbox directory allocated by the OS for temporary write operations (`Directory.systemTemp.path` or `path_provider.getTemporaryDirectory()`).
- **Cinema_Dark_Mode**: Visual mode enforced across full-screen media overlays (e.g. 9:16 vertical reels) where controls remain high-contrast white (`#FFFFFF`) regardless of the application's global theme.
- **Kinetic_Reels_Modal**: Full-screen vertical swipe video player displaying music clips, live performance reels, and open-verse challenges.
- **Mini_Player_Host**: Global Flutter overlay widget mounted above app routes that renders the floating music player pill/card/bar.
- **Modal_Sheet_Open_Count**: Reactive Riverpod integer provider tracking the number of active modal bottom sheets currently displayed on screen.
- **Procedural_Vision_Artwork**: Algorithmic fallback rendering system using deterministic color gradients and icons to display visual artwork without depending on external network URLs.
- **Owner_Profile_Provider**: Riverpod provider representing the currently authenticated creator profile (`id: 'creator_cern'`, `handle: '@cern'`).
- **Co_Sign_Badge**: Social proof badge indicating collective peer endorsement of a track or post (threshold: 25 co-signs for breakout promotion).
- **STD_UIUX_001**: Vhunambi design guideline mandating the exclusive use of Phosphor vector icons and banning raw Unicode emojis in functional UI elements.
- **Sync_Outbox_Service**: Local persistent queue that stores offline mutation records in a Hive box and synchronizes them with the backend API upon connectivity restoration.
- **Idempotency_Key**: Unique UUIDv4 string attached to every mutation ensuring identical requests are processed exactly once by the backend.

---

## Requirements

### Requirement 1: Android Filesystem Isolation & Safe Mixdown Bouncing

**User Story:** As a creator publishing an Open-Verse remix, I want the audio bounce process to write to a safe, sandboxed location on my device, so that mixdown creation never crashes with a read-only filesystem error.

#### Acceptance Criteria

1. **REQ-P44-FS-01**: `StemMixBounceService.bounceMixToFile` SHALL resolve any relative or bare filename inside `Directory.systemTemp.path` before initiating file write operations.
2. **REQ-P44-FS-02**: `OpenVerseRemixCockpitSheet._handlePublish` SHALL construct target file paths using `path.join(Directory.systemTemp.path, 'remix_open_verse_${DateTime.now().millisecondsSinceEpoch}.wav')`.
3. **REQ-P44-FS-03**: WHEN a `FileSystemException` occurs during file write (e.g., storage full, restricted permissions), `StemMixBounceService` SHALL catch the exception, log the diagnostic error, and fallback to returning a synthesized in-memory `Uint8List` buffer.
4. **REQ-P44-FS-04**: WHEN an in-memory buffer is returned as a fallback, the service SHALL encode the buffer into a standard `data:audio/wav;base64,...` URI string so downstream consumers can play or upload the mixdown without disk dependency.
5. **REQ-P44-FS-05**: THE mixdown progress indicator in `OpenVerseRemixCockpitSheet` SHALL complete smoothly from 0% to 100% without displaying red error snackbars on Android or iOS.

---

### Requirement 2: Cinema Dark Theme Enforcement for Full-Screen Reels

**User Story:** As a user browsing reels in Light Mode, I want the full-screen reel overlay to maintain high-contrast white action buttons, so that I can clearly see Like, Comment, Share, and Remix buttons over dark video surfaces.

#### Acceptance Criteria

1. **REQ-P44-REEL-01**: `KineticReelsModal` root widget SHALL be wrapped in `Theme(data: AppTheme.darkTheme, child: ...)` to insulate all internal components from the parent application's light theme.
2. **REQ-P44-REEL-02**: ALL action rail icon buttons (Like, Comment, Share, Translate, Remix) in `KineticReelsModal` SHALL explicitly bind their icon color to `AppColors.darkTextPrimary` (`#FFFFFF`).
3. **REQ-P44-REEL-03**: ALL action rail text labels (count badges, creator handles, audio titles) SHALL render in `AppColors.darkTextPrimary` or `AppColors.darkTextSecondary` with a subtle drop shadow (`BoxShadow(blurRadius: 4, color: Colors.black54)`).
4. **REQ-P44-REEL-04**: THE top navigation bar of `KineticReelsModal` SHALL render with a transparent-to-black gradient scrim and SHALL NOT flash white or light ivory when toggling or opening.
5. **REQ-P44-REEL-05**: WHEN the user exits `KineticReelsModal`, the application SHALL smoothly restore the global theme (Light or Dark) without visual artifacts.

---

### Requirement 3: Adaptive Mini-Player Hygiene & Modal Sheet Suppression

**User Story:** As a user opening modal dialogs or sheets, I want the floating mini-player pill to automatically hide, so that it never covers input fields or buttons on sheets.

#### Acceptance Criteria

1. **REQ-P44-MINI-01**: `MiniPlayerHost._shouldHide` SHALL return `true` WHEN `currentTrack == null` OR `currentTrack.title.trim().isEmpty` OR `currentTrack.title.trim().toLowerCase() == 'unknown'`.
2. **REQ-P44-MINI-02**: THE system SHALL provide a `modalSheetOpenCountProvider` (StateProvider<int>) in `navigation_providers.dart` initialized to `0`.
3. **REQ-P44-MINI-03**: EVERY modal bottom sheet (including `CreateKineticPostSheet`, `OpenVerseRemixCockpitSheet`, `DirectDawVocalUploadSheet`, `CreatorTippingSheet`) SHALL increment `modalSheetOpenCountProvider` upon entry and decrement upon disposal.
4. **REQ-P44-MINI-04**: `MiniPlayerHost._shouldHide` SHALL return `true` whenever `modalSheetOpenCountProvider > 0`.
5. **REQ-P44-MINI-05**: WHEN all modal bottom sheets are dismissed, the Mini-Player pill SHALL smoothly animate back into view (if an active, valid track is loaded).

---

### Requirement 4: Kinetic Post Composer Vision Fallbacks & Dynamic Multi-Vault Populators

**User Story:** As a creator attaching media to a Kinetic Post, I want the attachment dropdown to show relevant assets when I switch tabs, and I want preview thumbnails to display reliably without broken image icons.

#### Acceptance Criteria

1. **REQ-P44-COMP-01**: `CreateKineticPostSheet` preview thumbnail (80x80) SHALL check if the image URL is empty, invalid, or begins with `vision://`, and SHALL render `_buildVisionProceduralCanvas()` instead of a broken `Image.network` icon.
2. **REQ-P44-COMP-02**: WHEN the user selects the **Song** tab, the attachment dropdown SHALL populate from `libraryTracksProvider`.
3. **REQ-P44-COMP-03**: WHEN the user selects the **Beat** tab, the attachment dropdown SHALL populate from `beatsProvider` (marketplace beats & instrumentals).
4. **REQ-P44-COMP-04**: WHEN the user selects the **Voice DNA** tab, the attachment dropdown SHALL populate from `soundSignatureProvider` (cloned vocal presets and timbre signatures).
5. **REQ-P44-COMP-05**: WHEN the user selects the **Groove** tab, the attachment dropdown SHALL populate from `melodySketchpadProvider` (saved multitrack sketches and log-drum loops).

---

### Requirement 5: Post Attribution & Social Action Row Ergonomics

**User Story:** As a creator viewing social posts, I want my posts to show my authenticated profile, avoid self-follow buttons, and display co-sign badges cleanly without overlapping other buttons.

#### Acceptance Criteria

1. **REQ-P44-POST-01**: `CreateKineticPostSheet` SHALL construct new `SocialMusicPost` entities using the active profile from `ownerProfileProvider` (`displayName`, `creatorHandle`, `avatarUrl`, `creatorArchetype`).
2. **REQ-P44-POST-02**: `ExploreSocialPostCard` SHALL compare `post.creatorHandle` against `ownerProfile.handle`.
3. **REQ-P44-POST-03**: IF `post.creatorHandle == ownerProfile.handle`, `ExploreSocialPostCard` SHALL hide the `[ + Follow ]` button OR replace it with an informational `'Your Post'` chip.
4. **REQ-P44-POST-04**: THE `🔥 Co-Sign (x/25)` badge SHALL be positioned in the secondary badge row directly beneath the post caption, leaving the primary bottom action rail dedicated to standard engagement icons (Like, Comment, Repost, Tip, Share).
5. **REQ-P44-POST-05**: THE primary bottom action rail SHALL not cause horizontal overflow (`RenderFlex overflowed by X pixels`) on screen widths down to 320dp.

---

### Requirement 6: Profile Banner Light-Mode Contrast & Discovery Seed Integrity

**User Story:** As a user browsing artist profiles in Light Mode, I want all header icons to be legible, and I want artist profiles like `@sigwa` to have playable clips in their Clips tab.

#### Acceptance Criteria

1. **REQ-P44-PROF-01**: `ProfileBannerHeader` Share and Report icon buttons SHALL query `AppColors.textPrimaryOf(context)` so they render in high-contrast dark charcoal in Light Mode and crisp white in Dark Mode.
2. **REQ-P44-PROF-02**: `socialFeedProvider` mock data store SHALL seed at least one playable 9:16 Kinetic Reel clip associated with `creator_sigwa` (`@sigwa`).
3. **REQ-P44-PROF-03**: WHEN tapping the **Clips** tab on `@sigwa`'s profile, the grid SHALL display the seeded clip thumbnail rather than an empty placeholder message.
4. **REQ-P44-PROF-04**: Tapping the seeded clip SHALL launch `KineticReelsModal` targeting that specific clip.

---

### Requirement 7: Iconography Standard Compliance & Dead Code Purge

**User Story:** As a developer maintaining the codebase, I want all UI controls to use standard vector icons and want orphaned files removed, so that the app complies with design standards and stays lean.

#### Acceptance Criteria

1. **REQ-P44-EMOJI-01**: `CatalogFilterBar` category filter chips SHALL replace all raw Unicode emojis with corresponding `PhosphorIcons` (`musicNotes`, `speakerHigh`, `microphone`, `sparkle`, `slidersHorizontal`).
2. **REQ-P44-EMOJI-02**: THE following five orphaned, unmounted legacy files SHALL be safely deleted from the codebase:
   - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_header_section.dart`
   - `apps/vhunambi_client/lib/features/explore/presentation/widgets/creator_card.dart`
   - `apps/vhunambi_client/lib/features/explore/presentation/widgets/genre_radio_tile.dart`
   - `apps/vhunambi_client/lib/features/player/presentation/widgets/fluid_deck_switcher.dart`
   - `apps/vhunambi_client/lib/features/stems/data/fake_stem_download_service.dart`
3. **REQ-P44-EMOJI-03**: THE codebase SHALL compile with `flutter test` and `dart analyze` with zero unresolved imports or broken references resulting from the deletions.

---

### Requirement 8: Offline-First Client Mutation Outbox

**User Story:** As a mobile user in low-connectivity areas, I want my likes, tips, co-signs, and new posts to be saved locally immediately and synced automatically when connectivity returns, so that my actions are never lost.

#### Acceptance Criteria

1. **REQ-P44-SYNC-01**: THE app SHALL implement `SyncOutboxService` (`lib/core/sync/sync_outbox_service.dart`) backed by a dedicated Hive box (`vhunambi_sync_outbox_box`).
2. **REQ-P44-SYNC-02**: EVERY mutation record (`SyncMutationRecord`) SHALL contain:
   - `idempotencyKey` (UUIDv4)
   - `entityType` (`'post'`, `'track'`, `'tip'`, `'cosign'`, `'remix'`)
   - `action` (`'create'`, `'update'`, `'delete'`, `'cosign'`, `'tip'`)
   - `payload` (Map<String, dynamic>)
   - `createdAt` (ISO-8601 string)
   - `retryCount` (int)
   - `status` (`SyncStatus.pending`, `SyncStatus.syncing`, `SyncStatus.synced`, `SyncStatus.failed`)
3. **REQ-P44-SYNC-03**: `SyncOutboxService.enqueue()` SHALL write the mutation to Hive and immediately trigger an optimistic local Riverpod state update.
4. **REQ-P44-SYNC-04**: `SyncOutboxService.flush()` SHALL batch pending mutations and send them via `POST /api/sync/mutations`.
5. **REQ-P44-SYNC-05**: UPON receiving successful HTTP 200 with `{ applied: [idempotencyKeys] }`, `SyncOutboxService` SHALL remove or mark as synced the acknowledged keys.
6. **REQ-P44-SYNC-06**: `ProfileSettingsDrawer` SHALL render an `"Edge-Synced • All creations backed up"` status chip reflecting outbox queue health.
