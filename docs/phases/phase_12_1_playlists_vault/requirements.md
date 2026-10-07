# Phase 12.1 · Requirements — Playlists Vault Views & Hive Persistence

> **Phase:** 12.1 (Phase 12 Completion Patch)  
> **Codename:** `playlists-vault`  
> **Standard:** RFC 2119 (`MUST`, `SHALL`, `MAY`) & EARS (Easy Approach to Requirements Syntax)  
> **Traceability Anchor:** `docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md` (§2.1 Tab 1), `docs/phases/phase_12_lyrics_and_playlists/requirements.md` (REQ-PL-01, REQ-PL-09, REQ-PL-10)  

---

## 1. Functional Requirements

* **REQ-PV-01 (Hive-Backed Playlist Repository)**  
  The system MUST declare `AppConstants.playlistsBoxKey = 'vhunambi_playlists'` and implement `PlaylistRepository` backed by a persistent Hive box storing JSON maps, with automatic graceful fallback to an in-memory store in headless/test environments where Hive is uninitialized.

* **REQ-PV-02 (Library View Tab Switch & Empty State)**  
  WHEN the user navigates to `/library` with `LibraryCategory.playlists`, the system SHALL render `PlaylistsVaultView`. If `playlistsProvider` has 0 records, it MUST display `LibraryEmptyState(category: LibraryCategory.playlists)` with a `"Create your first playlist"` CTA that presents `CreatePlaylistDialog`.

* **REQ-PV-03 (Playlists Vault Grid & List Layouts)**  
  WHILE user playlists exist, `PlaylistsVaultView` MUST render playlist cards respecting `libraryViewModeProvider` (2-to-4 column square grid vs. dense list). Each item SHALL display the playlist title, track count, cumulative playtime, and an options menu (`[⋮]`).

* **REQ-PV-04 (Playlist Detail Cockpit Presentation)**  
  WHEN a user taps any playlist card, the system SHALL navigate to `PlaylistDetailView(playlist: playlist)`. The view MUST display:
  1. A hero header with mosaic / artwork, title, description, and track metrics.
  2. `"▶ Play All"` and `"🔀 Shuffle"` buttons.
  3. A table/list of tracks belonging to the playlist.
  4. Options to rename the playlist or delete the playlist.

* **REQ-PV-05 (Playlist Playback Trigger)**  
  WHEN the user taps `"▶ Play All"` or `"🔀 Shuffle"` in `PlaylistDetailView`, the system MUST resolve the playlist's `trackIds` into active `Track` objects and call `PlayerNotifier.playPlaylist(playlist, resolvedTracks)`.

* **REQ-PV-06 (Per-Track Removal)**  
  `PlaylistDetailView` MUST provide an individual remove trigger on each track row that calls `PlaylistsNotifier.removeTrackFromPlaylist(playlist.id, track.id)`.

---

## 2. Non-Functional Requirements

* **NFR-PV-01 (Design Token Strictness)**  
  All UI components MUST strictly use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, and `AppSpacing.*`. Zero raw hex values.
* **NFR-PV-02 (Analyzer Gate)**  
  `dart analyze .` MUST report **0 issues**.
* **NFR-PV-03 (Monotonic Test Growth)**  
  All 460 baseline tests MUST pass cleanly. Phase 12.1 SHALL add at least **15 new automated unit and widget tests** (target total: $\ge 475$).
