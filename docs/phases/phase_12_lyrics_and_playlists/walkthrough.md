# Phase 12 · Walkthrough — Studio Lyrics Review Cockpit & Playlists Queue Management

> **Phase:** 12
> **Codename:** `lyrics-and-playlists`
> **Standard:** RFC 2119 / EARS (see `requirements.md`)
> **Executed By:** Cline (Dual-Agent Symbiosis Protocol)
> **Verification:** `dart analyze .` = **0 issues** · `flutter test` = **100% passing**

---

## 1. Executive Summary

Phase 12 delivered both subsystems:

**Subsystem A — Studio Lyrics Review & Editing Cockpit**

* `LyricsSection` / `LyricsReviewDraft` domain models with a tolerant
  bracketed-tag parser (`[Intro]`, `[Verse 1]`, `[Chorus]`, `[Hook]`,
  `[Bridge]`, `[Outro]`) that also keeps trailing header metadata
  (`[Verse 1] • 8 bars`).
* `ILyricsGenerationService` + `FakeLyricsGenerationService` with authentic
  phrase banks for Tshivenḓa, isiZulu, Sepedi, Swahili and English, plus
  Amapiano/Gqom ad-lib packs. Output is deterministic per call index, so
  "Regenerate Lyrics" yields variation while tests stay exact.
* `LyricsReviewNotifier` (`lyricsReviewProvider`) with structural ⇄ raw
  markdown bi-directional synchronisation and a `hasEdits` dirty flag.
* `LyricsReviewModal`: centred dialog on desktop (> 1024px), 90% bottom sheet
  on mobile, stanza cards with inline editors, cultural idiom chip rail,
  raw markdown editor, regenerate, `Approve & Produce Beat ➔`.
* `StudioActionBar` now pauses the FSM in `GenerationPhase.generatingLyrics`,
  drafts the lyrics, moves to `GenerationPhase.reviewingLyrics` and opens the
  cockpit (REQ-LYR-01/02).

**Subsystem B — Playlists & Playback Queue Drawer**

* `PlaylistEntity` (+ JSON codec) and `IPlaylistRepository` with
  `InMemoryPlaylistRepository` for headless tests.
* `PlaylistsNotifier` (`playlistsProvider`) with full CRUD and
  `toggleTrackInPlaylist`.
* `PlayerNotifier` queue engine: `addToQueue`, `playNext`, `removeFromQueue`,
  `reorderQueue`, `clearUpcomingQueue`, `playPlaylist`.
* `QueueDrawer` with Now Playing hero card (live `WaveformBars` equalizer),
  reorderable Up Next list (drag handles + remove triggers) and a `Clear`
  header action; wired to the desktop transport bar (`📑`) and the expanded
  cockpit utility tray.
* `AddToPlaylistSheet` with search, membership checkboxes and an inline
  `+ Create New Playlist` creator; wired to the transport bar (`➕`) and
  `TrackActionsSheet`.

---

## 2. Task Ledger

| Task | Status | Evidence |
| --- | --- | --- |
| T12.1 Domain models | ✅ Complete | `lyrics_review_models_test.dart` (15) + `playlist_entity_test.dart` (8) |
| T12.2 Services & doubles | ✅ Complete | `fake_lyrics_generation_service_test.dart` (9) + `playlist_repository_test.dart` (8) |
| T12.3 Riverpod notifiers | ✅ Complete | `lyrics_review_provider_test.dart` (13) + `playlists_provider_test.dart` (9) |
| T12.4 Player queue engine | ✅ Complete | `player_queue_management_test.dart` (17) |
| T12.5 Lyrics review cockpit | ✅ Complete | `lyrics_review_modal_test.dart` (9) |
| T12.6 Queue drawer | ✅ Complete | `queue_drawer_test.dart` (9) |
| T12.7 Add to Playlist sheet | ✅ Complete | `add_to_playlist_sheet_test.dart` (7) |
| T12.7 Vault views (`/library?tab=playlists`, `PlaylistDetailView`) | ⏳ Deferred | Not started — see §7 |
| T12.8 Final gates & docs | ✅ Complete | `dart analyze .` = 0 issues; full suite = 460 passing tests |

**Phase 12 test additions:** 104 new automated tests (target was ≥ 35).
Full suite after Phase 12: **460 passing tests, 0 failures** — 0 regressions versus the
Phase 10 gate (321 tests); all Phase 11 notification suites are green in this run.

---

## 3. Files Created

**Subsystem A — Studio lyrics cockpit**

```
lib/features/studio/domain/models/lyrics_review_models.dart
lib/features/studio/domain/services/i_lyrics_generation_service.dart
lib/features/studio/data/services/fake_lyrics_generation_service.dart
lib/features/studio/presentation/providers/lyrics_review_provider.dart
lib/features/studio/presentation/widgets/lyrics_review_modal.dart
```

**Subsystem B — Playlists & queue**

```
lib/features/playlists/domain/models/playlist_entity.dart
lib/features/playlists/domain/repositories/i_playlist_repository.dart
lib/features/playlists/data/repositories/in_memory_playlist_repository.dart
lib/features/playlists/presentation/providers/playlists_provider.dart
lib/features/playlists/presentation/widgets/add_to_playlist_sheet.dart
lib/features/player/presentation/widgets/queue_drawer.dart
```

## 4. Files Modified

```
lib/features/player/presentation/providers/player_provider.dart   ← queue engine (T12.4)
lib/features/player/presentation/widgets/desktop_transport_bar.dart ← 📑 / ➕ wiring (T12.6/T12.7)
lib/features/player/presentation/widgets/expanded_cockpit_modal.dart ← Queue utility item (T12.6)
lib/features/studio/domain/models/studio_form_state.dart           ← resolvedTitle (T12.5)
lib/features/studio/presentation/providers/studio_form_provider.dart ← FSM handoff (T12.5)
lib/features/studio/presentation/widgets/studio_action_bar.dart     ← review pause (T12.5)
lib/features/library/presentation/widgets/track_actions_sheet.dart  ← playlist picker (T12.7)
```

## 5. Test Inventory (Phase 12)

| Suite | Tests |
| --- | --- |
| `test/features/studio/domain/models/lyrics_review_models_test.dart` | 15 |
| `test/features/playlists/domain/models/playlist_entity_test.dart` | 8 |
| `test/features/studio/data/services/fake_lyrics_generation_service_test.dart` | 9 |
| `test/features/playlists/data/repositories/playlist_repository_test.dart` | 8 |
| `test/features/studio/presentation/providers/lyrics_review_provider_test.dart` | 13 |
| `test/features/playlists/presentation/providers/playlists_provider_test.dart` | 9 |
| `test/features/player/player_queue_management_test.dart` | 17 |
| `test/features/studio/presentation/widgets/lyrics_review_modal_test.dart` | 9 |
| `test/features/player/widgets/queue_drawer_test.dart` | 9 |
| `test/features/playlists/presentation/widgets/add_to_playlist_sheet_test.dart` | 7 |

## 6. Design Decisions & Deviations

1. **Parser tolerance.** Text before the first bracketed tag becomes an
   implicit `[Verse]`, and trailing header metadata (`[Verse 1] • 8 bars`) is
   preserved inside `LyricsSection.header` so structured edits round-trip.
2. **Idiom insertion.** `insertIdiom` appends to the last stanza by default
   (the widget layer has no cursor model) and opens a fresh `[Verse]` when the
   draft has no stanzas left; `sectionId` targets a specific stanza.
3. **Queue opening.** `addToQueue` / `playNext` seed `state.queue` with the
   currently active track before appending, so `currentIndex` always points at
   a row inside `queue` (the seeded player starts with a track but no queue).
4. **Index integrity.** `removeFromQueue` / `reorderQueue` clamp out-of-range
   indices and keep `currentIndex` pinned to the same track where possible.
5. **Up Next slicing.** `QueueDrawer` renders only rows after the active
   index and translates drag indices back to absolute queue indices before
   delegating to `PlayerNotifier`.
6. **`playPlaylist` signature.** Retains the `PlaylistEntity` parameter for
   REQ-PL-10 fidelity while playing from the resolved `tracks` list.
7. **Draft preservation.** Closing the cockpit keeps the draft in memory
   (REQ-LYR-09) and only prompts when `hasEdits` is `true`; `clear()` is the
   explicit release path.
8. **Pipeline title.** `StudioFormState.resolvedTitle` derives the title from
   the first four prompt words when the creator has not set a custom title.
9. **Test hygiene.** Widget suites pin desktop viewports, avoid
   `pumpAndSettle` (the Now Playing equalizer repeats forever) and dispose
   `ProviderContainer`s inside the test body so `PlayerNotifier`'s 1-second
   ticker never trips the pending-timer assertion.
10. **`ReorderableListView.onReorderItem`.** The SDK deprecates `onReorder`
    after v3.41.0-0.0.pre, so `QueueDrawer` uses `onReorderItem` and converts
    the adjusted index back to the raw pre-removal index
    (`newIndex >= oldIndex ? newIndex + 1 : newIndex`) that
    `PlayerNotifier.reorderQueue` adjusts internally — keeping the tested
    queue-engine contract intact and the analyzer at 0 issues.

## 7. Remaining Work (Deferred)

* **`PlaylistsVaultView` at `/library?tab=playlists`** and
  **`PlaylistDetailView`** (Play All / Shuffle / rename / delete) —
  REQ-PL-09 and REQ-PL-10 UI surfaces. The engine they need
  (`playPlaylist`, `playlistsProvider`, `IPlaylistRepository`) is delivered
  and tested.
* **Hive-backed `PlaylistRepository`** for production persistence
  (`AppConstants.playlistsBoxKey` still needs to be declared); the in-memory
  repository satisfies the headless-test half of REQ-PL-01.
