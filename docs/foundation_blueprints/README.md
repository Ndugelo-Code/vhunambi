# Vhunambi Foundation Blueprints (Phase 0)

> **Client Architecture Specification for Cross-Platform Desktop & Mobile (Windows, macOS, Android, iOS)**  
> Cloned directly from the production web application at [vhunambi.com](https://vhunambi.com).

---

## 1. Executive Purpose

The `foundation_blueprints/` directory serves as the **Single Source of Truth (SSOT)** for the Vhunambi cross-platform Flutter/Dart client before any Flutter code, packages, or platform channels are touched.

### Etymology & Brand Identity
* **Vhunambi** (with an **i**) derives from Tshivenḓa, translating directly to *"the talent or ability to sing"*, reflecting the core mission of enabling African and global musical creators through artificial intelligence and community collaboration.
* Keeping uniform nomenclature across directories, models, and assets prevents cross-platform refactoring friction.

---

## 2. The 5-Layer Dissection Rule

Every view, subsystem, and component in Vhunambi is specified across five deterministic layers before implementation:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Visual Tokens & Styling Primitives                │
│  (Surfaces, brand accents, typography scales, radii, borders)│
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Component Tree & Layout Scaffolding               │
│  (Slivers, sticky headers, responsive grids, sheet dialogs)  │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: State Models & Reactive Providers                 │
│  (Riverpod state trees, immutable models, audio providers)   │
├─────────────────────────────────────────────────────────────┤
│  Layer 4: Platform Native Behavior                          │
│  (Desktop windowing, mobile gestures, media notifications)  │
├─────────────────────────────────────────────────────────────┤
│  Layer 5: Flutter Implementation Blueprints                 │
│  (Widget contracts, Slivers, cached image pipelines)       │
└─────────────────────────────────────────────────────────────┘
```

1. **Layer 1: Visual Tokens & Styling Primitives**: Exact hex color values, typography hierarchies, surface depths, border radii, and padding metrics.
2. **Layer 2: Component Tree & Layout Scaffolding**: Deterministic widget hierarchies covering sticky headers, responsive layouts (Mobile viewport <600px, Tablet 600–1024px, Desktop >1024px), scrolling slivers, and modal sheets.
3. **Layer 3: State Models & Reactive Providers**: Riverpod state management contracts, immutable Freezed/json_serializable entities, cache strategies, and event dispatches.
4. **Layer 4: Platform Native Behavior**: Operating system integration including keyboard navigation, window frame handling for Windows/macOS, audio lock screen & media notification controls, and touch physics.
5. **Layer 5: Flutter Implementation Blueprints**: Deterministic Flutter code structures, avoiding ad-hoc styling and guaranteeing performance with `const` constructors, item extent calculations, and memory-safe audio streaming.

---

## 3. Planned Blueprint Roadmap

The foundation architecture is divided into the following standardized documents:

| Index | Document | Scope & Target Capabilities |
| :--- | :--- | :--- |
| **00** | [`00_SYSTEM_DESIGN_TOKENS.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md) | Universal color palette, typography scale, elevation, border radii, animation tokens, and regional genre gradients. |
| **01** | [`01_EXPLORE_PAGE_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/01_EXPLORE_PAGE_SPEC.md) | Route `/explore`: Global search/navigation scaffolding, segmented tabs, African Music Charts banner, 2-column cover grids, track lists, creator showcase, 12-genre radio grid, and 4-tier filter engine. |
| **02** | [`02_PERSISTENT_PLAYER_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/02_PERSISTENT_PLAYER_SPEC.md) | Persistent bottom mini-player dock, expanded audio cockpit modal, interactive waveform scrubber, playlist queue management, and background audio service. |
| **03** | [`03_CREATE_STUDIO_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/03_CREATE_STUDIO_SPEC.md) | AI music generation cockpit (`+ Create`), prompt engineering interface, genre/style selector chips, stems separator, and generation status states. |
| **04** | [`04_LIBRARY_VAULT_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md) | Personal music vault, playlists, collections, beats, commercial licensing records, and offline cached audio. |
| **05** | [`05_MARKETPLACE_AND_LANDING_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/05_MARKETPLACE_AND_LANDING_SPEC.md) | Route `/market` (Beats Marketplace) & `/` (Full Marketing Funnel, 20+ genre showcase, 6 pillars, 4 pricing tiers). |
| **06** | [`06_TRACK_AND_CREATOR_PROFILES_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/06_TRACK_AND_CREATOR_PROFILES_SPEC.md) | Routes `/track/:id` (Track Breakdown, Lyrics, Stems), `/profile/:id` (Public Artist), and `/profile/me` (Creator Studio). |
| **07** | [`07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md) | Desktop Extended DAW Transport Bar, Mobile Mini-Player Strip, Real-Time Generation Pipeline Card, and Notifications Drawer. |

> **Status: Phase 0 Blueprinting Suite 100% Complete (Blueprints 00 through 07 finalized on disk).**

---

## 4. Architectural Rules of Engagement

1. **Zero Guesswork**: If a layout or interaction is not in the corresponding blueprint, reference the production web application at `https://vhunambi.com` and document it before coding.
2. **Strict Dart Type Safety**: All state models must be strongly typed with explicit nullability handling.
3. **Design Token Uniformity**: Never hardcode hex values or ad-hoc padding in UI widgets. All visual attributes must resolve through `AppColors`, `AppTypography`, `AppRadius`, and `AppSpacing`.
4. **Audio Resiliency**: Audio playback state must persist across route transitions using a global audio service decoupled from UI lifecycle.
