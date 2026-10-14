# System Modernization 9 · Blueprint — Creator DNA & Adaptive Intelligence

> **System:** M9 (Modernization Sprint) / Phase 01.1 (Onboarding Enhancement)  
> **Codename:** `creator-dna-adaptive-intelligence`  
> **Status:** 🟡 SPECIFICATION  
> **Target App:** `apps/vhunambi_client`  
> **Flutter / Dart:** 3.44+ / 3.x+  
> **State Management:** Riverpod 2.x (`StateNotifierProvider`, `Provider`)  
> **Persistence:** Hive Local Storage (`AppConstants.creatorDnaBoxKey`) with headless in-memory fallback  
> **Accessibility Standard:** WCAG 2.1 AA / Apple HIG (44×44px hit bounds)  
> **Companion Documents:**  
> — `docs/phases/creator-dna-adaptive-intelligence/requirements.md`  
> — `docs/phases/creator-dna-adaptive-intelligence/design.md`  
> — `docs/phases/creator-dna-adaptive-intelligence/tasks.md`

---

## 1. Executive Summary & Vision

Vhunambi is not a tool — it is a **companion that learns you**. System M9 establishes the foundational adaptive intelligence layer that transforms the app from a static generator into a living musical partner that grows more accurate, more personal, and more useful the more a creator uses it.

At the heart of this is the **Creator DNA Profile** — a locally persisted, continuously evolving model of a user's musical identity, taste, and creative habits. It is seeded during onboarding and enriched by every interaction thereafter: every play, skip, like, genre filter, language selection, studio session, and generation submission.

### The DNA Feedback Loop

```
Onboarding (Seed) ──────────────────────────────────────────────────────────┐
                                                                             ▼
Passive Behaviour Events ──► DNA Weight Engine ──► CreatorDnaProfile ──► Studio Auto-Fill
(plays, likes, skips,                              (locally persisted)  Explore Ranking
 generation history,                                                    Home Greeting
 genre filters,                                                         Recommendations
 language picks)                                                        Notification Priority
     ▲                                                                       │
     └───────────────────────── User Creates & Explores ◄───────────────────┘
```

The more a user interacts with Vhunambi, the more the system aligns with their musical DNA — making song generation feel effortless, recommendations feel eerily accurate, and the entire experience feel like a companion that truly knows them.

### Non-Negotiable Architectural Invariants

1. **Zero Code Generation**: No `build_runner`, no `@HiveType`. Hand-rolled `toJson()` / `fromJson()` with untyped Hive box (`Box? _box`) and automatic in-memory fallback using `AppConstants.creatorDnaBoxKey`.
2. **Preserve Canonical 5-Tab RootShell**: No new bottom nav tabs. DNA settings accessed via Profile → Creator DNA section.
3. **Preserve `StudioFormState` Contract**: Studio providers read DNA to *pre-fill* defaults only. The existing `StudioFormState` entity and all studio notifiers remain untouched — DNA provides suggested defaults, not forced values.
4. **Preserve `ArtistProfileEntity` Contract**: DNA enrichment is appended to profile data, not a replacement.
5. **Privacy by Default**: All DNA data is computed and stored 100% on-device. Zero raw user tracking leaves the device. DNA is never transmitted to the backend in raw form.
6. **Design Token Discipline**: Zero raw hex colors. All DNA strength meters, genre badges, and mood gradients map to `AppColors` tokens.
7. **Ergonomic 44×44px Hit Bounds**: All onboarding selections, DNA insight cards, and studio suggestion chips satisfy minimum 44×44px touch bounding boxes.

---

## 2. System Context & Data Flow

```mermaid
graph TD
    subgraph Onboarding Gateway (DNA Seed)
        OB1[Step 1: Welcome & Mission]
        OB2[Step 2: Creative Identity & Role]
        OB3[Step 3: Genre & Heritage DNA]
        OB4[Step 4: Language & Cultural Roots]
        OB5[Step 5: Sound Signature Seed]
        OB1 --> OB2 --> OB3 --> OB4 --> OB5
        OB5 -->|writeInitialDna| DNA[(CreatorDnaProfile\nHive Box)]
    end

    subgraph Passive DNA Capture Engine
        EV1[TrackPlayEvent]
        EV2[TrackLikeEvent]
        EV3[TrackSkipEvent]
        EV4[GenerationSubmitEvent]
        EV5[GenreFilterEvent]
        EV6[ExploreScrollDepthEvent]
        EV1 & EV2 & EV3 & EV4 & EV5 & EV6 -->|recordEvent| DnaNotifier
        DnaNotifier -->|recomputeWeights| DNA
    end

    subgraph DNA-Powered Surfaces
        STU[Studio Auto-Fill\nDNA-seeded StudioFormState defaults]
        EXP[Explore Feed\nDNA-ranked track ordering]
        HOME[Home Dashboard\nPersonalized greeting, DNA digest card]
        NOTIF[Notifications\nDNA-priority alert filtering]
        PROF[Profile: Creator DNA Card\nDNA Strength % + genre breakdown]
    end

    DNA --> STU
    DNA --> EXP
    DNA --> HOME
    DNA --> NOTIF
    DNA --> PROF
```

---

## 3. Onboarding Enhancement — 5-Step DNA Seed Flow

### Current State (3 steps)
```
Step 0: Welcome & Vision
Step 1: Genre + Language Preference Chips
Step 2: Ready Screen + 10 Credits
```

### Target State (5 purposeful steps)
```
Step 0: Welcome & Companion Promise
Step 1: Creative Identity (role + experience level)
Step 2: Genre DNA (multi-select with regional variants)
Step 3: Language & Cultural Roots (primary + secondary)
Step 4: Sound Signature Seed (BPM feel, vocal energy, mood palette)
Step 5: DNA Activation Screen + Credit Gift
```

### Step Wireframes (Mobile 390×844px)

**Step 0 — Welcome & Companion Promise**
```
┌─────────────────────────────────────────┐
│  ░░░░░ STATUS BAR ░░░░░                 │
│                              [Skip]     │ ← 44px
│                                         │
│         ╔══════════╗                    │
│         ║  ⬡ DNA   ║ ← 100×100 animated │
│         ║ emblem   ║   amber pulse rings│
│         ╚══════════╝                    │
│                                         │
│    VHUNAMBI LEARNS YOU                  │ ← displayLarge
│                                         │
│  The more you create and explore,       │
│  the more it becomes like you.          │ ← bodyLarge / textSecondary
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 🎵 Genre intelligence from plays │   │ ← feature badges
│  │ 🎤 Vocal taste from likes        │   │
│  │ 🌍 Cultural roots from usage     │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ○──────────────────   [Continue →]     │ ← step dots + 44px CTA
└─────────────────────────────────────────┘
```

**Step 1 — Creative Identity**
```
┌─────────────────────────────────────────┐
│  [←]                         [Skip]     │
│                                         │
│  Who are you as a creator?              │ ← titleLarge
│  (Select your primary role)             │ ← bodyLarge
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  🎹 Producer      ← 44px card   │   │
│  │  🎤 Vocalist                     │   │
│  │  ✍️  Songwriter                  │   │
│  │  🎧 Multi-hyphenate              │   │
│  │  👂 Music Lover / Fan            │   │
│  └──────────────────────────────────┘   │
│                                         │
│  How experienced are you?               │
│  ┌────────┐  ┌──────────┐  ┌────────┐  │
│  │ Newbie │  │ Growing  │  │  Pro   │  │ ← 44px toggle buttons
│  └────────┘  └──────────┘  └────────┘  │
│                                         │
│  ●○○○○○     [Continue →]               │
└─────────────────────────────────────────┘
```

**Step 2 — Genre DNA**
```
┌─────────────────────────────────────────┐
│  [←]                         [Skip]     │
│                                         │
│  Your Genre DNA                         │ ← titleLarge
│  Pick the sounds that move you          │
│                                         │
│  🔥 South African                       │ ← section label
│  [Amapiano] [Gqom] [Kwaito]             │
│  [Maskandi] [Afro House] [Bubblegum]    │
│                                         │
│  🌍 Pan-African                         │
│  [Afrobeats] [Highlife] [Bongo Flava]   │
│  [Afropop]  [Azonto]   [Coupé-Décalé]  │
│                                         │
│  🎵 Global Influences                   │
│  [Gospel] [R&B / Soul] [Hip Hop]        │
│  [Electronic] [Jazz]                    │
│                                         │
│  ●●○○○○     [Continue →]               │
└─────────────────────────────────────────┘
```

**Step 3 — Language & Cultural Roots**
```
┌─────────────────────────────────────────┐
│  [←]                         [Skip]     │
│                                         │
│  Language & Cultural Roots              │ ← titleLarge
│  Select your primary voice language     │
│  (used in AI vocal generation)          │
│                                         │
│  🇿🇦 Southern Africa                    │
│  [Tshivenḓa] [isiZulu] [isiXhosa]       │
│  [Sepedi] [Setswana] [Afrikaans]         │
│  [Xitsonga] [siSwati]                   │
│                                         │
│  🌍 East & West Africa                  │
│  [Kiswahili] [Yoruba] [Twi] [Amharic]  │
│                                         │
│  🌐 Global                              │
│  [English] [French] [Portuguese]        │
│                                         │
│  Primary: [Tshivenḓa ✓]                │
│  Secondary: (multi-select above)        │
│                                         │
│  ●●●○○○     [Continue →]               │
└─────────────────────────────────────────┘
```

**Step 4 — Sound Signature Seed**
```
┌─────────────────────────────────────────┐
│  [←]                         [Skip]     │
│                                         │
│  Your Sound Signature                   │ ← titleLarge
│  Calibrate your production feel         │
│                                         │
│  ── Tempo Feel ──                       │
│  [Slow 60–80] [Medium 80–120]           │
│  [Fast 120–145] [Hyperspeed 145+]       │
│                                         │
│  ── Vocal Energy ──                     │
│  [Intimate / Soft] [Balanced]           │
│  [High Intensity]                       │
│                                         │
│  ── Mood Palette ──                     │
│  [🌅 Uplifting] [🌙 Reflective]         │
│  [🔥 Energetic] [💫 Spiritual]          │
│  [🎭 Raw / Gritty] [🌊 Chill]           │
│                                         │
│  ●●●●○○     [Activate My DNA →]        │
└─────────────────────────────────────────┘
```

**Step 5 — DNA Activation**
```
┌─────────────────────────────────────────┐
│                                         │
│         ╔══════════╗                    │
│         ║  🧬 DNA  ║ ← 100×100 animated │
│         ║ charged! ║   green pulse      │
│         ╚══════════╝                    │
│                                         │
│   Your Creator DNA Is Activated         │ ← displayLarge / bold
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  DNA Strength: 18% 🟡           │   │ ← Progress bar (grows with use)
│  │  (Keep exploring to grow it)     │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ── Your DNA Snapshot ──               │
│  🎵 Amapiano, Gqom              │
│  🌍 Tshivenḓa (primary)          │
│  🎹 Producer · Newbie            │
│  ⚡ Fast · High Intensity         │
│                                         │
│  ⚡ 10 Free Song Credits Loaded         │
│                                         │
│        [Start Creating ✨]              │ ← 44px primary CTA
└─────────────────────────────────────────┘
```

---

## 4. Component Hierarchy Tree

```
creator-dna-adaptive-intelligence/
├── domain/
│   ├── entities/
│   │   └── creator_dna_profile.dart       ← Core DNA model (toJson/fromJson)
│   ├── models/
│   │   ├── behavior_event.dart             ← Event types & payloads
│   │   ├── dna_signal_weight.dart          ← Per-genre/language weight map
│   │   └── onboarding_flow_state.dart      ← Extended 5-step flow model
│   └── repositories/
│       └── creator_dna_repository.dart    ← Hive box + in-memory fallback
├── presentation/
│   ├── providers/
│   │   ├── creator_dna_provider.dart      ← DnaNotifier + creatorDnaProvider
│   │   ├── dna_studio_defaults_provider.dart ← Studio form pre-fill derivation
│   │   └── onboarding_providers.dart      ← Extended OnboardingNotifier (modify)
│   ├── views/
│   │   └── onboarding_view.dart           ← Expanded 5-step view (modify)
│   └── widgets/
│       ├── dna_activation_screen.dart     ← Step 5 DNA reveal widget
│       ├── dna_strength_meter.dart        ← Animated DNA % progress bar
│       ├── dna_genre_badge.dart           ← Token-colored genre chip
│       ├── creative_role_card.dart        ← 44px role selection cards
│       ├── sound_signature_picker.dart    ← BPM / energy / mood selector
│       └── dna_insight_card.dart          ← Home dashboard DNA card
```

---

## 5. State Machine: DNA Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│                  DNA LIFECYCLE STATES                    │
│                                                          │
│  UNINITIALIZED ──[completeOnboarding]──► SEEDED          │
│                                          │               │
│                              [recordEvent]               │
│                                          ▼               │
│                                       LEARNING           │
│                               (strength: 18-60%)         │
│                                          │               │
│                              [30+ events]                │
│                                          ▼               │
│                                      CALIBRATED          │
│                               (strength: 60-80%)         │
│                                          │               │
│                              [100+ sessions]             │
│                                          ▼               │
│                                       ATTUNED            │
│                               (strength: 80-100%)        │
│                                                          │
│  Any state ──[resetDna]──► UNINITIALIZED                 │
└─────────────────────────────────────────────────────────┘
```

---

## 6. DNA Signal Taxonomy

### Onboarding Seed Signals (initial weight: 1.0x)
| Signal | Captured At | DNA Field Updated |
|---|---|---|
| Primary Role | Step 1 | `creativeRole` |
| Experience Level | Step 1 | `experienceLevel` |
| Selected Genres | Step 2 | `genreWeights` (each = 1.0) |
| Primary Language | Step 3 | `primaryLanguage` |
| Secondary Languages | Step 3 | `languageWeights` |
| Tempo Preference | Step 4 | `tempoPreference` |
| Vocal Energy | Step 4 | `vocalEnergyPreference` |
| Mood Palette | Step 4 | `moodWeights` |

### Passive Behaviour Signals (cumulative weight updates)
| Event | DNA Weight Delta | Decay? |
|---|---|---|
| `TrackPlayEvent` (full listen >80%) | genre +0.15, language +0.10 | No |
| `TrackPlayEvent` (partial <30%) | genre -0.05 | No |
| `TrackLikeEvent` | genre +0.30, language +0.20, mood +0.25 | No |
| `TrackSkipEvent` (<5s) | genre -0.10 | No |
| `GenerationSubmitEvent` | genre +0.40, language +0.35, tempo +0.30, vocal +0.25 | No |
| `GenreFilterEvent` | genre +0.20 | No |
| `ExploreScrollDepthEvent` (genre section) | genre +0.08 | No |
| `TrackShareEvent` | genre +0.20, mood +0.15 | No |

---

## 7. DNA-Powered Surface Integration Points

### 7.1 Studio Auto-Fill (`dnaStudioDefaultsProvider`)
When a user opens the studio with a seeded DNA profile, the `StudioFormState` is pre-populated:
- `genre` ← top-weighted genre from `genreWeights`
- `language` ← `primaryLanguage`
- `tempo` ← `tempoPreference` → mapped to `TempoBracket`
- `vocalEnergy` ← `vocalEnergyPreference` → mapped to `VocalEnergy`
- `mood` ← top-weighted mood from `moodWeights`
- `vocalGender` ← inferred from DNA history (if undetermined, default `mixed`)

The user can override any field at any time — these are suggestions, not locks.

### 7.2 Home Dashboard DNA Card
- Compact DNA strength meter (shows % with animated fill)
- Top 2 genres displayed as token-colored badge chips
- "Your DNA is growing — explore more Amapiano to strengthen it" contextual tip

### 7.3 Explore Feed Ranking
- `DnaExploreRanker` applies a soft-rank boost to tracks whose genre/language match top DNA weights
- Implemented as a pure Dart function — no network calls, no async operations

### 7.4 Notification Priority Filtering
- Algorithmic notifications (e.g., `trackTrending`) are prioritized if track genre matches DNA top-2

---

## 8. Persistence Architecture

```
AppConstants.creatorDnaBoxKey = 'vhunambi_creator_dna'

Box? _box (untyped)
  └── 'dna_profile' → Map<String, dynamic>  (CreatorDnaProfile.toJson())
  └── 'behavior_log' → List<Map>             (BehaviorEvent[] last 500 events)

In-memory fallback:
  → CreatorDnaProfile.initial() used when Hive box cannot be opened
  → All reads degrade gracefully to defaults
  → All writes silently no-op when in-memory mode is active
```

---

## 9. Verification Gates

| Gate | Command | Pass Criteria |
|---|---|---|
| Static analysis | `dart analyze lib test` | 0 issues |
| DNA unit tests | `flutter test test/features/onboarding/` | All pass |
| DNA provider tests | `flutter test test/features/creator_dna/` | All pass |
| Studio defaults test | `flutter test test/features/studio/` | No regressions |
| Full suite regression | `flutter test` | ≥ 813 + new tests, 0 failures |
