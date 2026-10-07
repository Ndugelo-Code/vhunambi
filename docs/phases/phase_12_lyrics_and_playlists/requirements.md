# Phase 12 · Requirements — Studio Lyrics Review Cockpit & Playlists Queue Management

> **Phase:** 12  
> **Codename:** `lyrics-and-playlists`  
> **Standard:** RFC 2119 (`MUST`, `SHALL`, `MAY`) & EARS (Easy Approach to Requirements Syntax)  
> **Traceability Anchor:** `docs/foundation_blueprints/03_CREATE_STUDIO_SPEC.md`, `02_PERSISTENT_PLAYER_SPEC.md`, `04_LIBRARY_VAULT_SPEC.md`, `07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`  

---

## 1. Subsystem A: Studio Lyrics Review & Editing Cockpit

### Functional Requirements

* **REQ-LYR-01 (FSM Review Pause)**  
  WHEN a user taps `"Write Lyrics First"` in `StudioActionBar` with `LyricsMode.aiWrite`, the system SHALL transition `StudioFormState.phase` to `GenerationPhase.generatingLyrics`, generate lyrical content via `ILyricsGenerationService`, and transition to `GenerationPhase.reviewingLyrics`.

* **REQ-LYR-02 (Lyrics Review Modal Presentation)**  
  WHILE the studio form is in `GenerationPhase.reviewingLyrics`, the system MUST present `LyricsReviewModal` (as a centered elevated dialog on desktop viewports > 1024px and an expandable 90% bottom sheet on mobile viewports < 768px).

* **REQ-LYR-03 (Structured Stanza Dissection)**  
  The system SHALL parse raw lyrical text into a structured list of `LyricsSection` entities, recognizing bracketed tags (`[Intro]`, `[Verse]`, `[Verse 1]`, `[Chorus]`, `[Hook]`, `[Bridge]`, `[Outro]`).

* **REQ-LYR-04 (Inline Stanza Editing)**  
  WHEN a user taps the edit trigger on any stanza card, the system SHALL enable inline multiline editing for that section while preserving structural section headers.

* **REQ-LYR-05 (Raw Full-Text Editor Toggle)**  
  The system MUST provide a toggle between the Section Stanza Card view and a raw multiline markdown editor (`_RawLyricsEditor`), synchronizing changes bi-directionally between both modes.

* **REQ-LYR-06 (Cultural Idiom & Ad-Lib Injection)**  
  WHEN the user taps a cultural idiom chip (e.g., Tshivenḓa, isiZulu, Sepedi, Swahili), the system SHALL insert the phrase at the current cursor position or append it to the active stanza.

* **REQ-LYR-07 (Lyrics Regeneration)**  
  WHEN the user triggers `"Regenerate Lyrics"`, the system SHALL call `ILyricsGenerationService.generateLyrics()` with a randomized stylistic seed and update the review state without resetting the prompt or studio parameters.

* **REQ-LYR-08 (Approve & Queue Synthesis Handoff)**  
  WHEN the user taps `"Approve & Produce Beat ➔"`, the system MUST:
  1. Save the reviewed lyrics into `StudioFormState.customLyrics`.
  2. Transition `StudioFormState.phase` to `GenerationPhase.queued`.
  3. Dispatch `GenerationPipelineNotifier.startGeneration(title: ..., genre: ...)` with the approved lyrics payload.
  4. Dismiss the lyrics review modal and display `GenerationPipelineCard`.

* **REQ-LYR-09 (Dismissal & Draft Preservation)**  
  WHEN the user cancels or closes the review modal, the system SHALL prompt for confirmation if changes were made and preserve the draft in memory if dismissed.

---

## 2. Subsystem B: Playlists & Playback Queue Drawer

### Functional Requirements

* **REQ-PL-01 (Playlist Domain Entity & Storage)**  
  The system SHALL define an immutable `PlaylistEntity` with `id`, `title`, `description`, `coverImageUrl`, `trackIds`, `createdAt`, and `updatedAt`. It MUST persist user playlists in local storage via `IPlaylistRepository` (backed by Hive `playlistsBoxKey` with headless test in-memory fallback).

* **REQ-PL-02 (Playlist CRUD State Notifier)**  
  The system MUST provide `PlaylistsNotifier` (`playlistsProvider`) exposing:
  - `createPlaylist(String title, {String? description})`
  - `updatePlaylist(String id, {String? title, String? description})`
  - `deletePlaylist(String id)`
  - `addTrackToPlaylist(String playlistId, String trackId)`
  - `removeTrackFromPlaylist(String playlistId, String trackId)`

* **REQ-PL-03 (Interactive Queue Drawer UI)**  
  The system SHALL provide `QueueDrawer` accessible via the queue icon (`Icons.queue_music_rounded`, `📑`) on the Desktop Transport Bar and Expanded Cockpit Modal.

* **REQ-PL-04 (Now Playing Hero Section)**  
  `QueueDrawer` MUST prominently display the currently active track with dynamic artwork, artist, title, elapsed duration, and animated equalizer bars.

* **REQ-PL-05 (Reorderable Upcoming Queue)**  
  `QueueDrawer` SHALL render upcoming tracks in a `ReorderableListView`, allowing users to drag and drop rows via `Icons.drag_handle_rounded` to reorder the upcoming playback queue.

* **REQ-PL-06 (Queue Removal & Clear)**  
  `QueueDrawer` MUST provide:
  1. Individual track removal triggers (`Icons.close_rounded`) on each queue item.
  2. A `"Clear Queue"` action in the header that removes all upcoming tracks while keeping the active track playing.

* **REQ-PL-07 (Add to Queue & Play Next Actions)**  
  `PlayerNotifier` SHALL provide:
  - `addToQueue(Track track)`: Appends track to the end of `state.queue`.
  - `playNext(Track track)`: Inserts track immediately following `state.currentIndex`.

* **REQ-PL-08 (Add to Playlist Modal Sheet)**  
  The system SHALL provide `AddToPlaylistSheet` containing a searchable list of the user's playlists with checkbox status indicating presence of the current track, plus an inline `+ New Playlist` creator.

* **REQ-PL-09 (Library Vault Playlists Tab Integration)**  
  WHILE the user navigates to `/library?tab=playlists` (Category `LibraryCategory.playlists`), the system SHALL display populated playlists in a responsive grid/list with track counts. If 0 playlists exist, it SHALL display `LibraryEmptyState` with a `"Create your first playlist"` CTA.

* **REQ-PL-10 (Play Entire Playlist Bridge)**  
  WHEN a user taps `"Play All"` on any playlist, `PlayerNotifier.playPlaylist(PlaylistEntity playlist, List<Track> tracks)` MUST replace the playback queue with the playlist's tracks and immediately begin playing track index 0.

---

## 3. Non-Functional Requirements & Invariants

* **NFR-12-01 (Design Token Compliance)**  
  Zero raw hexadecimal color literals or ad-hoc padding. All widgets MUST use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, and `AppSpacing.*`.

* **NFR-12-02 (Headless Test Safety)**  
  All new repositories, services, and widgets MUST run cleanly in `flutter_test` without animation leaks, pending timers, or OS file locking dependencies. `FakeLyricsGenerationService` and `InMemoryPlaylistRepository` MUST be provided for testing.

* **NFR-12-03 (Static Analysis Gate)**  
  `dart analyze .` MUST report **0 issues** across `apps/vhunambi_client`.

* **NFR-12-04 (Monotonic Test Growth & Zero Regressions)**  
  All 345+ baseline tests (Phases 1–11) MUST continue to pass (100%). Phase 12 SHALL add at least **35 new automated unit and widget tests**.
