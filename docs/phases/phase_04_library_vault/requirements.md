# Phase 4 Requirements: Library & User Asset Vault (`/library`)

> **Specification Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `MAY`)  
> **Traceability Root:** `REQ-LIB`

---

## 1. Top Bar & Scaffolding Requirements

- **REQ-LIB-01 (Responsive Header):**
  - The Library view **MUST** render a top bar conforming to the responsive specification:
    - On Mobile (< 768px): Brand emblem, credit token chip (`⚡ 10 songs left`), notification bell, overflow menu, and square create action button.
    - On Desktop (> 1024px): Back chevron, brand emblem, centered `"My Library"` breadcrumb, credit chip, notification bell, `📊 Analytics` button, and solid orange `✨ Create` pill.

- **REQ-LIB-02 (Category Navigation Rail):**
  - The Library view **MUST** provide a horizontally scrollable rail containing 6 category tabs:
    1. `♪ Songs` (Default active, index 0)
    2. `≡♪ Playlists` (Index 1)
    3. `💿 Collections` (Index 2)
    4. `🛍️ Beats` (Index 3)
    5. `⚖️ Licensing` (Index 4)
    6. `🗑️ Trash` (Index 5)
  - Selecting a category tab **MUST** update the active category state and filter the rendered vault items immediately.

---

## 2. Empty State & Populated Vault Requirements

- **REQ-LIB-03 (Universal Empty State):**
  - When the active category contains zero records, the UI **MUST** display:
    - A 48x48px squircle container (`surfaceElevated`, border `borderSubtle`, corner radius 14px) with category icon.
    - An informative headline (e.g. `"No songs yet"`).
    - Muted contextual description instructing the user on how to populate the vault.
    - A solid orange CTA button (`✨ Create your first song`) that navigates to the Studio Creation Cockpit.

- **REQ-LIB-04 (Track Search & Filtering):**
  - The populated view **MUST** provide a search input allowing real-time text matching against track titles and artist names.
  - The view **SHALL** provide a view mode toggle between 2-column grid and dense list formats.

- **REQ-LIB-05 (Track Item Metadata Presentation):**
  - Each track item **MUST** display:
    - Cover artwork square (resolved with genre gradient from `AppGradients` or cached image).
    - Track title and creator name.
    - Duration (formatted as `mm:ss`) and genre badge.
    - Offline status indicator chip (`⬇️ Offline` or `☁️ Cloud`).
    - Contextual menu trigger button (`⋮`).

---

## 3. Track Actions & Management Requirements

- **REQ-LIB-06 (Contextual Action Sheet):**
  - Tapping the contextual trigger (`⋮`) **MUST** present a bottom modal sheet containing:
    - `Play Now`: Inserts track into `playerStateProvider` and begins audio playback.
    - `Add to Playlist`: Prompts playlist assignment.
    - `Stem Separation`: Initiates stem separation.
    - `Download Offline`: Marks track for local caching.
    - `View Commercial License`: Opens licensing sheet.
    - `Share Song`: Copies track URL.
    - `Move to Trash` (or `Restore` if in Trash tab).

- **REQ-LIB-07 (Soft Deletion & Trash Restoration):**
  - Deleting a track from the library **MUST** mark the track as soft-deleted (`isDeleted: true`) and move it to the `Trash` tab.
  - From the `Trash` tab, the user **MUST** be able to restore the track or permanently purge it.

- **REQ-LIB-08 (Persistence & State Management):**
  - The Library **MUST** expose Riverpod providers for category selection, search queries, view mode, and track lists.
