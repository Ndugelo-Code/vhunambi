# Phase 4 Blueprint: Library & User Asset Vault (`/library`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Cross-Platform)  
> **Route Path:** `/library` (Mounted in Tab Index 3 of `RootShell`)  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com/library`)

---

## 1. Visual Architecture & Layout Geometry

The User Library (`/library`) acts as the personal vault for user-generated tracks, stems, curated playlists, licensing certificates, and offline audio downloads. The UI adapts responsively between touch-optimized mobile screens and high-density desktop production environments:

```
Desktop Scaffolding (> 1024px):
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [ < ] (🎵) VHUNAMBI                 My Library               [⚡ 10 songs left] [🔔] [📊 Analytics] [⋮] [✨ Create] │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                                                                                                      │
│  [ ♪ Songs ]  [ ≡♪ Playlists ]  [ 💿 Collections ]  [ 🛍️ Beats ]  [ ⚖️ Licensing ]  [ 🗑️ Trash ]        │
│                                                                                                      │
│                                                ┌────┐                                                │
│                                                │ ♪  │  <-- Squircle Container (48x48, #141418)       │
│                                                └────┘                                                │
│                                             No songs yet                                             │
│                  Head to the Studio and generate your first song — it'll appear here instantly.      │
│                                      [ ✨ Create your first song ]                                    │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘

Mobile Viewport (< 768px):
┌──────────────────────────────────────────────────────────────────────┐
│ (🎵) VHUNAMBI                   [⚡ 10 songs left]  [🔔]  [⋮]  [✨]  │ <-- Mobile Header
├──────────────────────────────────────────────────────────────────────┤
│ [ ♪ Songs ]  [ ≡♪ Playlists ]  [ 💿 Collections ]  [ 🛍️ Beats ] ...  │ <-- Horizontal Rail
│                                                                      │
│                                ┌────┐                                │
│                                │ ♪  │                                │
│                                └────┘                                │
│                             No songs yet                             │
│                  Head to the Studio and generate your                │
│                 first song — it'll appear here instantly.            │
│                                                                      │
│                     [ ✨ Create your first song ]                    │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│    [Home]        [Explore]        [✨ Create]     ─[Library]─  [Market]│ <-- Active Orange Bar
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Category Taxonomy & Metadata Tabs

A horizontally scrollable pill rail directly beneath the top navigation bar:
- `♪ Songs` (Index 0, default active): Individual generated music tracks.
- `≡♪ Playlists` (Index 1): User-curated custom playlists.
- `💿 Collections` (Index 2): EPs, albums, and concept projects.
- `🛍️ Beats` (Index 3): Standalone instrumental beats with BPM tags and key signatures.
- `⚖️ Licensing` (Index 4): Ownership split sheets and PDF licensing certificates.
- `🗑️ Trash` (Index 5): Soft-deleted tracks with 30-day grace period and one-tap restore.

### Styling Tokens
- **Active Pill:** Background `AppColors.brandPrimary` (`#F97316`), text `AppColors.brandContrast` (`#000000`), bold font.
- **Inactive Pill:** Background `AppColors.surfaceSecondary` (`#1B1B22`), border `AppColors.borderSubtle` (`#2D2D38`), text `AppColors.textSecondary`.

---

## 3. Empty State Pattern (Universal Design Token)

When the active category contains 0 records:
- Centered squircle container: `48x48px`, surface `AppColors.surfaceElevated` (`#141418`), border `AppColors.borderSubtle` (`#2D2D38`), corner radius `14px`.
- Centered icon: Vector musical note `Icons.music_note_rounded` (`#FFFFFF`, size 22).
- Headline: `"No songs yet"` (`AppTypography.titleLarge`, bold, white).
- Subtext: `"Head to the Studio and generate your first song — it'll appear here instantly."` (`AppTypography.bodySmall`, text secondary, max width `340px`).
- Primary CTA: Solid orange pill button `[ ✨ Create your first song ]` pushing to Tab 2 (`StudioView`).

---

## 4. Populated Track Vault (List & Grid Layouts)

When tracks exist:
- Filter/Search strip: Search input pill (`"Search my songs..."`), filter button, and Grid/List toggle (`⊞ / ☰`).
- Track Card / Row Components:
  - Artwork square with genre gradient or cover thumbnail.
  - Title, duration, creation timestamp, and genre badge.
  - Offline badge indicator (`⬇️ Offline` vs `☁️ Cloud`).
  - Contextual overflow menu button (`⋮`):
    - `▶ Play Now`
    - `➕ Add to Playlist`
    - `🎛️ Stem Separation`
    - `⬇️ Download Offline`
    - `⚖️ View Commercial License`
    - `🔗 Share Song`
    - `🗑️ Move to Trash`
