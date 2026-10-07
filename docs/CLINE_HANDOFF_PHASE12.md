# Phase 12 Master Handoff: Studio Lyrics Review Cockpit & Playlists Queue Management

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 12. Read this first — it captures exact requirements, architectural invariants, full class designs, and the execution checklist.
>
> **Generated At:** 2026-09-26T23:36:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Baseline:** `dart analyze .` = **0 issues** | `flutter test` = **100% passing**  
> **Target Test Count:** **≥ 380 tests (≥ 35 new tests)**

---

## 1. Phase 12 Objectives & Scope

Phase 12 combines two critical architectural capabilities scheduled across earlier milestones:

### Subsystem A: Studio Lyrics Review & Editing Cockpit (Closing Phase 10 Loop)
1. **Interactive Review FSM Pause:** In the Studio Cockpit (`/create`), when `lyricsMode == LyricsMode.aiWrite`, the primary CTA says `"📄 Write Lyrics First"`. Tapping it triggers `GenerationPhase.generatingLyrics` $\rightarrow$ `GenerationPhase.reviewingLyrics`, pausing before beat production.
2. **`LyricsReviewModal`:** Centered dialog (> 1024px) or 90% bottom sheet (< 768px) presenting generated stanzas (`[Intro]`, `[Verse 1]`, `[Chorus]`, etc.) with inline line editing and rhyme notes.
3. **Cultural Idiom & Ad-Lib Injection Tray:** One-tap chips for regional idioms (Tshivenḓa, isiZulu, Sepedi, Swahili, Amapiano log-drum vocal ad-libs).
4. **Bi-directional Raw Markdown Editor:** One-tap toggle to edit full raw lyrics text, updating the structured section model.
5. **Approve & Produce Beat Handoff:** Saves reviewed lyrics to `customLyrics`, transitions to `GenerationPhase.queued`, and dispatches `GenerationPipelineNotifier.startGeneration(...)` to produce the full beat.

### Subsystem B: Playlists & Playback Queue Drawer (Completing Player & Vault)
1. **`PlaylistEntity` & Repository:** Immutable model + `IPlaylistRepository` (`InMemoryPlaylistRepository` for headless tests, Hive box in production).
2. **`PlaylistsNotifier` & Provider:** Full playlist CRUD in `lib/features/playlists/presentation/providers/playlists_provider.dart`.
3. **`PlayerNotifier` Queue Enhancements:** `addToQueue`, `playNext`, `removeFromQueue`, `reorderQueue`, `clearUpcomingQueue`, `playPlaylist`.
4. **Interactive `QueueDrawer`:** Slide-in drawer on desktop transport bar (`📑`) and mobile cockpit modal with live Now Playing equalizer card and `ReorderableListView` drag-and-drop upcoming queue.
5. **`AddToPlaylistSheet`:** Searchable playlist picker with checkmarks and inline `+ New Playlist` creator.
6. **Library Vault Integration:** Populated playlist grid/list at `/library?tab=playlists` and `PlaylistDetailView`.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_12_lyrics_and_playlists/`:

- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_lyrics_and_playlists/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_lyrics_and_playlists/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_lyrics_and_playlists/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_12_lyrics_and_playlists/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`. No raw `Color(0xFF...)` literals.
2. **Riverpod 2.x only:** `StateNotifierProvider`, `Provider`. No `ChangeNotifier`, no `provider` package.
3. **Headless Test Safety:** Every test double must run cleanly without OS file locking, animation leaks, or uncancelled timers. Always provide `FakeLyricsGenerationService` and `InMemoryPlaylistRepository`.
4. **Collision Safety:** Do NOT import `RepeatMode` from Flutter SDK; use `AudioRepeatMode` (`off`, `all`, `one`).
5. **Zero Regressions:** All baseline tests (Phases 1–11) must continue to pass cleanly.

---

## 4. File Map — Everything to Create/Modify

### New Files to CREATE

```
lib/features/studio/
  domain/
    models/lyrics_review_models.dart                    ← T12.1
    services/i_lyrics_generation_service.dart           ← T12.2
  data/services/fake_lyrics_generation_service.dart     ← T12.2
  presentation/
    providers/lyrics_review_provider.dart               ← T12.3
    widgets/lyrics_review_modal.dart                    ← T12.5

lib/features/playlists/
  domain/
    models/playlist_entity.dart                         ← T12.1
    repositories/i_playlist_repository.dart             ← T12.2
  data/repositories/in_memory_playlist_repository.dart  ← T12.2
  presentation/
    providers/playlists_provider.dart                   ← T12.3
    widgets/add_to_playlist_sheet.dart                  ← T12.7
    views/
      playlists_vault_view.dart                         ← T12.7
      playlist_detail_view.dart                         ← T12.7

lib/features/player/presentation/widgets/
  queue_drawer.dart                                     ← T12.6

test/features/
  studio/
    domain/models/lyrics_review_models_test.dart        ← T12.1
    data/services/fake_lyrics_generation_service_test.dart ← T12.2
    presentation/
      providers/lyrics_review_provider_test.dart        ← T12.3
      widgets/lyrics_review_modal_test.dart             ← T12.5
  playlists/
    domain/models/playlist_entity_test.dart             ← T12.1
    data/repositories/playlist_repository_test.dart     ← T12.2
    presentation/
      providers/playlists_provider_test.dart            ← T12.3
      widgets/add_to_playlist_sheet_test.dart           ← T12.7
  player/
    player_queue_management_test.dart                   ← T12.4
    widgets/queue_drawer_test.dart                      ← T12.6
```

### Existing Files to MODIFY

```
lib/features/player/presentation/providers/player_provider.dart ← T12.4 (queue methods)
lib/features/player/presentation/widgets/desktop_transport_bar.dart ← T12.6 & T12.7 (wire 📑 and ➕)
lib/features/player/presentation/widgets/expanded_cockpit_modal.dart ← T12.6 (wire queue trigger)
lib/features/studio/presentation/widgets/studio_action_bar.dart ← T12.5 (trigger lyrics modal)
lib/features/library/presentation/views/library_view.dart ← T12.7 (mount playlists tab view)
```

---

## 5. Verification Gates

```powershell
cd apps/vhunambi_client

# Unit and Widget test gates
flutter test test/features/studio/domain/models/lyrics_review_models_test.dart
flutter test test/features/playlists/domain/models/playlist_entity_test.dart
flutter test test/features/studio/data/services/fake_lyrics_generation_service_test.dart
flutter test test/features/playlists/data/repositories/playlist_repository_test.dart
flutter test test/features/studio/presentation/providers/lyrics_review_provider_test.dart
flutter test test/features/playlists/presentation/providers/playlists_provider_test.dart
flutter test test/features/player/player_queue_management_test.dart
flutter test test/features/studio/presentation/widgets/lyrics_review_modal_test.dart
flutter test test/features/player/widgets/queue_drawer_test.dart
flutter test test/features/playlists/presentation/widgets/add_to_playlist_sheet_test.dart

# Final Phase 12 verification gates (MUST REPORT 0 ISSUES & ALL TESTS PASSED)
dart analyze .
flutter test
```
