# Tasks Document: Phase 44 Frontend Video Defect Eradication & Edge Outbox

## Implementation Checklist

### Track A: Critical Video Defect Eradication & Visual Polish

- [ ] **Task 1: Resolve Android Read-Only FS Trap & Memory Fallback**
  - [ ] 1.1 In `apps/vhunambi_client/lib/features/player/data/services/stem_mix_bounce_service.dart`, update `bounceMixToFile` to ensure all relative paths prepend `Directory.systemTemp.path`.
  - [ ] 1.2 Wrap file write block in `try / catch(FileSystemException)` to catch OS errors (`errno = 30`).
  - [ ] 1.3 Add fallback generation returning in-memory `Uint8List` wrapped in `data:audio/wav;base64,...` data URI.
  - [ ] 1.4 In `apps/vhunambi_client/lib/features/social/presentation/widgets/open_verse_remix_cockpit_sheet.dart`, sanitize `targetPath` using `path.join(Directory.systemTemp.path, filename)`.
  - [ ] 1.5 Verify mixdown generation test passes without filesystem exceptions.
  - _Requirements: REQ-P44-FS-01, REQ-P44-FS-02, REQ-P44-FS-03, REQ-P44-FS-04, REQ-P44-FS-05_

- [ ] **Task 2: Enforce Cinema Dark Theme on Full-Screen Kinetic Reels**
  - [ ] 2.1 In `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`, wrap root widget tree with `Theme(data: AppTheme.darkTheme)`.
  - [ ] 2.2 Bind all action rail buttons (Like, Comment, Share, Translate, Remix) explicitly to `AppColors.darkTextPrimary` (`#FFFFFF`).
  - [ ] 2.3 Add drop shadow (`BoxShadow(blurRadius: 4, color: Colors.black54)`) to all reel icon buttons and counters.
  - [ ] 2.4 Verify top navigation bar renders with transparent gradient scrim and never flashes white in Light Mode.
  - _Requirements: REQ-P44-REEL-01, REQ-P44-REEL-02, REQ-P44-REEL-03, REQ-P44-REEL-04, REQ-P44-REEL-05_

- [ ] **Task 3: Implement Mini-Player Hygiene & Modal Bottom Sheet Suppression**
  - [ ] 3.1 In `apps/vhunambi_client/lib/core/navigation/navigation_providers.dart`, introduce `modalSheetOpenCountProvider` (StateProvider<int>).
  - [ ] 3.2 In `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`, update `_shouldHide()` to return true if `modalSheetOpenCount > 0`.
  - [ ] 3.3 In `mini_player_host.dart`, update `_shouldHide()` to return true if `currentTrack == null` or title is empty or `'Unknown'`.
  - [ ] 3.4 Wire `modalSheetOpenCountProvider` increment/decrement lifecycle in `CreateKineticPostSheet`, `OpenVerseRemixCockpitSheet`, and other major modal sheets.
  - _Requirements: REQ-P44-MINI-01, REQ-P44-MINI-02, REQ-P44-MINI-03, REQ-P44-MINI-04, REQ-P44-MINI-05_

- [ ] **Task 4: Procedural Vision Composer Fallbacks & Dynamic Multi-Vault Populator**
  - [ ] 4.1 In `apps/vhunambi_client/lib/features/social/presentation/widgets/create_kinetic_post_sheet.dart`, replace broken 80x80 image placeholder with procedural Vision gradient canvas fallback.
  - [ ] 4.2 Connect attachment dropdown to `libraryTracksProvider` when Song tab is active.
  - [ ] 4.3 Connect attachment dropdown to `beatsProvider` when Beat tab is active.
  - [ ] 4.4 Connect attachment dropdown to `soundSignatureProvider` when Voice DNA tab is active.
  - [ ] 4.5 Connect attachment dropdown to `melodySketchpadProvider` when Groove tab is active.
  - _Requirements: REQ-P44-COMP-01, REQ-P44-COMP-02, REQ-P44-COMP-03, REQ-P44-COMP-04, REQ-P44-COMP-05_

- [ ] **Task 5: Post Attribution & Social Action Row Ergonomics**
  - [ ] 5.1 In `create_kinetic_post_sheet.dart`, author posts using authenticated user details from `ownerProfileProvider` (`cern` / `@cern`).
  - [ ] 5.2 In `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`, compare post creator with logged-in user handle and hide the `[ + Follow ]` button on own posts.
  - [ ] 5.3 Move the `🔥 Co-Sign (x/25)` badge into the secondary badge row beneath the caption.
  - [ ] 5.4 Reorganize primary bottom action rail to prevent overflow on 320dp-360dp mobile screens.
  - _Requirements: REQ-P44-POST-01, REQ-P44-POST-02, REQ-P44-POST-03, REQ-P44-POST-04, REQ-P44-POST-05_

- [ ] **Task 6: Profile Banner Light-Mode Contrast & Discovery Seed Integrity**
  - [ ] 6.1 In `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_banner_header.dart`, bind Share and Report icons to `AppColors.textPrimaryOf(context)`.
  - [ ] 6.2 In `apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart`, seed a playable kinetic reel for `creator_sigwa`.
  - [ ] 6.3 Verify tapping Clips tab on `@sigwa` profile renders active playable reel thumbnail.
  - _Requirements: REQ-P44-PROF-01, REQ-P44-PROF-02, REQ-P44-PROF-03, REQ-P44-PROF-04_

- [ ] **Task 7: Iconography Standard Compliance (STD-UIUX-001) & Dead Code Purge**
  - [ ] 7.1 In `apps/vhunambi_client/lib/features/explore/presentation/widgets/catalog_filter_bar.dart`, replace raw Unicode emojis with Phosphor vector icons.
  - [ ] 7.2 Safely delete orphaned files:
    - `explore_header_section.dart`
    - `creator_card.dart`
    - `genre_radio_tile.dart`
    - `fluid_deck_switcher.dart`
    - `fake_stem_download_service.dart`
  - [ ] 7.3 Run `dart analyze` to ensure zero unresolved imports or dead references.
  - _Requirements: REQ-P44-EMOJI-01, REQ-P44-EMOJI-02, REQ-P44-EMOJI-03_

---

### Track D: Offline-First Client Mutation Outbox

- [ ] **Task 8: Implement SyncOutboxService & Local Durability**
  - [ ] 8.1 Create `apps/vhunambi_client/lib/core/sync/sync_outbox_service.dart` backed by Hive box `vhunambi_sync_outbox_box`.
  - [ ] 8.2 Define `SyncMutationRecord` model with `idempotencyKey`, `entityType`, `action`, `payload`, `createdAt`, `retryCount`, and `status`.
  - [ ] 8.3 Implement `enqueue()`, `flush()`, and exponential backoff retry loop.
  - [ ] 8.4 Wire durability status badge into `ProfileSettingsDrawer`.
  - _Requirements: REQ-P44-SYNC-01, REQ-P44-SYNC-02, REQ-P44-SYNC-03, REQ-P44-SYNC-04, REQ-P44-SYNC-05, REQ-P44-SYNC-06_

---

### Verification & Testing Tasks

- [ ] **Task 9: Phase 44 Test Suite**
  - [ ] 9.1 Author `test/features/social/phase44_video_fixes_and_edge_outbox_test.dart` testing:
    - Safe temp path resolution and in-memory WAV fallback
    - Cinema dark theme lock and contrast tokens
    - Mini-player suppression on 'Unknown' and open modal sheets
    - Post creation with `ownerProfileProvider` and self-follow suppression
    - `SyncOutboxService` enqueue, deduplication, and flush
  - [ ] 9.2 Execute `flutter test` $\rightarrow$ 100% green.
  - [ ] 9.3 Run `dart analyze lib test` $\rightarrow$ 0 issues.
