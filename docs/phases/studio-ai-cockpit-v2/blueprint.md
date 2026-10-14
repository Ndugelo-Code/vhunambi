# System Modernization 10 · Blueprint — Studio AI Cockpit v2

> **System:** M10 (Modernization Sprint) / Phase 04 (Studio Renaissance)  
> **Codename:** `studio-ai-cockpit-v2`  
> **Status:** 🟡 SPECIFICATION  
> **Target App:** `apps/vhunambi_client`  
> **Flutter / Dart:** 3.44+ / 3.x+  
> **State Management:** Riverpod 2.x (existing `studioFormProvider`, `lyricsReviewProvider`, `generationPipelineProvider`)  
> **Persistence:** Hive Local Storage (`AppConstants.studioSessionBoxKey`) — session draft recovery  
> **Audit Standard:** `docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md`  
> **Companion Documents:**  
> — `docs/phases/studio-ai-cockpit-v2/requirements.md`  
> — `docs/phases/studio-ai-cockpit-v2/design.md`  
> — `docs/phases/studio-ai-cockpit-v2/tasks.md`

---

## 1. Executive Summary & Vision

The Studio is the soul of Vhunambi — the place where African music creation actually happens. It currently has a solid architectural foundation: a 3-tab `IndexedStack` layout (`Compose`, `Voice`, `Crate & MPC`), a rich `StudioFormState` domain model, a live generation pipeline FSM with WebSocket progress streaming, a Lyrics Review Cockpit with per-stanza editing, Bantu Voice LoRA engine with 5 timbre profiles, Heritage Crate Browser, MPC Slicer, and `AdvancedOptionsAccordion` with 10 configurable parameters.

**The studio works. It just doesn't yet feel like a companion that guides, protects, and empowers the creator.**

System M10 elevates the studio from a **capable tool** into a **deeply intelligent creative cockpit** by solving five creator pain points that the current implementation completely leaves unaddressed:

### The 5 Pain Points This System Solves

| # | Pain Point | Current State | M10 Solution |
|---|---|---|---|
| 1 | **Blank prompt paralysis** | User stares at an empty text box with no idea how to describe a song in technical terms. They open another AI chat to get a better prompt. | **Conversational Prompt Intelligence** — natural language input + DNA-enhanced suggestion + AI refinement |
| 2 | **Session loss frustration** | User spends 15 min configuring the studio, accidentally navigates away, and returns to a completely blank form. 90% give up and never return. | **Ghost Session Persistence** — Hive-backed auto-save of every form change; invisible recovery on return |
| 3 | **Blind option selection** | Options like `TempoBracket.fast`, `VocalMode.rap`, `VocalEnergy.intense` mean nothing without hearing an example. User guesses and gets wrong results. | **Option Preview System** — standardized audio/text micro-preview anchored to every selectable option |
| 4 | **Unguided custom lyrics** | Custom lyrics mode drops the user into a blank text field with zero structure. No guidance on intro vs verse vs chorus, no genre-appropriate suggestions, no correction. | **Guided Lyrics Composer** — sequential section-by-section guided authoring with genre-aware AI suggestions |
| 5 | **Locked language** | User writes lyrics in isiZulu, decides Tshivenḓa would sound better, and has no way to switch. Manual translation is required. | **Bantu Lyric Language Switcher** — one-tap 100% accurate translation between all 8 Bantu languages |

---

## 2. What Already Exists (Preserved, Not Replaced)

The following capabilities are **excellent as-is** and must be preserved with zero regressions:

| Component | File | Preserve As-Is |
|---|---|---|
| 3-tab `IndexedStack` layout | `studio_view.dart` | ✅ |
| `StudioFormState` immutable model | `studio_form_state.dart` | ✅ |
| `StudioFormNotifier` + all setters | `studio_form_provider.dart` | ✅ |
| 4 DNA preset methods | `studio_form_provider.dart` | ✅ |
| `RegionalGenreSelector` with search + grid | `regional_genre_selector.dart` | ✅ (enhance only) |
| `MultilingualLanguageSelector` | `multilingual_language_selector.dart` | ✅ |
| `AdvancedOptionsAccordion` 10-param system | `advanced_options_accordion.dart` | ✅ (enhance only) |
| `LyricsReviewModal` stanza card cockpit | `lyrics_review_modal.dart` | ✅ (extend only) |
| `LyricsReviewNotifier` bi-directional sync | `lyrics_review_provider.dart` | ✅ |
| `GenerationPipelineNotifier` FSM + WebSocket | `generation_pipeline_providers.dart` | ✅ |
| `BantuVoiceDeck` 5 timbre cards | `bantu_voice_deck.dart` | ✅ (enhance only) |
| `CrateBrowserDeck` + `MpcSlicerDeck` | existing files | ✅ |
| `ReferenceAudioDropzone` | existing | ✅ |
| `LivePhoneticAlignmentPreview` | existing | ✅ |

---

## 3. System Architecture: New Components Added to Existing Structure

```
studio/
├── domain/
│   ├── models/
│   │   ├── studio_form_state.dart             ← ADD: sessionId, lastSavedAt fields
│   │   ├── studio_session_draft.dart          ← NEW: persisted session snapshot
│   │   ├── option_preview_descriptor.dart     ← NEW: audio/text preview metadata
│   │   └── lyrics_section_scaffold.dart       ← NEW: guided composer section model
│   └── services/
│       └── studio_prompt_intelligence.dart    ← NEW: DNA+AI prompt enhancement
├── data/
│   └── services/
│       ├── studio_session_repository.dart     ← NEW: Hive session persistence
│       └── bantu_translation_service.dart     ← NEW: Bantu lyrics translation
├── presentation/
│   ├── providers/
│   │   ├── studio_form_provider.dart          ← MODIFY: wire session save on change
│   │   ├── studio_session_provider.dart       ← NEW: session recovery + dirty state
│   │   └── lyrics_review_provider.dart        ← MODIFY: add guided composer mode
│   ├── views/
│   │   └── studio_view.dart                   ← MODIFY: session recovery banner
│   └── widgets/
│       ├── prompt_input_box.dart              ← MODIFY: conversational intelligence
│       ├── advanced_options_accordion.dart    ← MODIFY: option preview chips
│       ├── lyrics_review_modal.dart           ← MODIFY: guided composer integration
│       ├── studio_session_recovery_banner.dart ← NEW
│       ├── prompt_intelligence_overlay.dart   ← NEW
│       ├── option_preview_chip.dart           ← NEW: standardized preview chip
│       ├── guided_lyrics_composer.dart        ← NEW: section-by-section authoring
│       ├── lyric_section_card.dart            ← NEW: per-section guided editor
│       ├── genre_atmosphere_library.dart      ← NEW: genre-specific suggestion bank
│       └── bantu_language_switcher.dart       ← NEW: lyrics language translation
```

---

## 4. Feature 1: Conversational Prompt Intelligence

### Current State
The `PromptInputBox` has a raw text field, 3 static preset chips, and an `inspireMe()` random seed. There is zero AI assistance or DNA connection.

### Target State
The prompt box becomes a **conversational intelligence surface** with three tiers:

```
┌──────────────────────────────────────────────────────────────┐
│  ✨ Describe your song                        [DNA pre-fill] │ ← Header row
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  "i want a female zulu amapiano song with deep log          │ ← Natural language input
│   drums called mehlo"                                        │   (conversational, imperfect)
│                                                              │
├──────────────────────────────────────────────────────────────┤
│  🧬 DNA SUGGESTION                               [Apply ✓]  │ ← DNA enhancement panel
│  "Soulful Amapiano anthem with deep log drum                │   (appears after 1.5s typing pause)
│   basslines and a smooth solo female vocalist               │
│   delivering emotive isiZulu melodic phrasing."             │
├──────────────────────────────────────────────────────────────┤
│  Auto-applied: [Genre: Amapiano ✓] [Lang: isiZulu ✓]        │ ← Form auto-fill chips
│  [Vocal: Female ✓] [Tempo: Medium ✓]                        │   (click to undo any)
└──────────────────────────────────────────────────────────────┘
```

### DNA Enhancement Logic
1. User types a casual description (any length, any quality)
2. After a 1.5s typing pause, `StudioPromptIntelligence.enhance()` is called:
   - Parses entities from the prompt: genre mentions, language mentions, artist gender, mood keywords, instrument names
   - Merges parsed entities with `CreatorDnaProfile` top signals
   - Generates an enriched prompt using genre-appropriate vocabulary
   - Returns suggested `StudioFormState` field overrides (genre, language, vocalGender, tempo, mood)
3. The enhanced prompt appears in a dismissable suggestion panel below the input
4. Auto-fill chips show which fields would be changed — user can individually accept or decline each
5. Tapping `Apply` applies the enhanced prompt AND all non-declined field suggestions

### Inspiration Seeds (Enhanced)
The 3 static preset chips expand to `9 genre-specific seed prompts` organized by DNA top genre. Seeds cycle dynamically based on DNA profile, so a Gqom-heavy user sees different seeds than an Afrobeats user.

---

## 5. Feature 2: Ghost Session Persistence

### Current State
`StudioFormNotifier` has a `reset()` method that wipes all state. There is **zero persistence** between app sessions. Navigating away = total state loss.

### Target State
Every change to `StudioFormState` triggers an **async Hive auto-save** (debounced 800ms). When the user returns to the Studio tab, any unsaved session is detected and offered for recovery via a subtle non-intrusive banner.

### Session Lifecycle
```
User opens studio
       │
       ├─ [No saved session] ──► Fresh empty form (current behaviour)
       │
       └─ [Saved session found] ──► SessionRecoveryBanner appears at top
                                     "You have an unfinished session from
                                      2h ago — [Resume] or [Start Fresh]"
                                          │                │
                                       Resume          Start Fresh
                                       (restore)       (clear + dismiss)
```

### Session Data Persisted
- All `StudioFormState` fields except `phase`, `generationProgress`, `errorMessage`
- Custom lyrics text (critical — this is the most painful to lose)
- Selected `BantuVoiceProfile` and `DialectInflectionConfig`
- Reference audio path
- `sessionId` (UUID), `savedAt` timestamp

### Auto-Save Triggers
- Any `StudioFormNotifier` setter call → debounced 800ms → `StudioSessionRepository.saveSession()`
- Lyrics editor text change → immediate save (no debounce, lyrics are precious)

---

## 6. Feature 3: Option Preview System

### The Problem
The `AdvancedOptionsAccordion` has critical parameters — `TempoBracket`, `VocalMode`, `VocalEnergy`, `SongStructure`, `LyricsMode` — presented as raw chips or toggle rows with zero context. Users have no idea what `VocalMode.spokenWord` vs `VocalMode.melodic` will sound like, or what `SongStructure.freestyle` produces vs `SongStructure.standard`.

### The Solution: `OptionPreviewChip`
A standardized `OptionPreviewChip` widget that wraps every selectable option across the studio with a consistent preview affordance — without cluttering the UI for users who don't want it.

```
┌──────────────────────────────────────────────────────────────┐
│  Vocal Mode                                                  │
│                                                              │
│  [Melodic ♪ ⓘ]  [Rap 🎤 ⓘ]  [Spoken Word 📢 ⓘ]            │
│  [Choir 🎵 ⓘ]   [Auto ✦ ⓘ]                                 │
│                                                              │
│         ↑                                                    │
│   ⓘ = info icon — tap to expand preview                     │
└──────────────────────────────────────────────────────────────┘

  When ⓘ is tapped on "Rap 🎤":
  ┌────────────────────────────────┐
  │  🎤 Rap / Spoken Delivery       │ ← mini overlay card
  │  Rhythmic lyric delivery with   │
  │  emphasis on syllable timing   │
  │  and flow over melodic singing. │
  │                                 │
  │  Best for: Hip Hop, Gqom,       │
  │  Afrobeats                      │
  │                                 │
  │  [▶ Hear Example]  [Got It]     │ ← optional 3s audio clip
  └────────────────────────────────┘
```

### Preview Descriptor Library
All 5 `TempoBracket` values, 4 `VocalMode` values, 3 `VocalEnergy` values, 4 `SongStructure` values, and 4 `LyricsMode` values get a `OptionPreviewDescriptor` entry with:
- `title` — human-readable label
- `description` — 2-sentence plain explanation
- `bestForGenres` — 2-3 genre names this option works best with
- `sampleClipId` — optional asset reference for a 3-second audio example clip (for future use — M11)

The preview system is **non-blocking** — users who never tap `ⓘ` have zero experience change. Users who need guidance get rich, standardized context.

---

## 7. Feature 4: Guided Lyrics Composer

### Current State
`LyricsMode.myOwn` drops the user into a raw `TextField` via `AdvancedOptionsAccordion`. Zero guidance, zero structure, zero suggestions.

### Target State
A **Guided Lyrics Composer** modal that walks the user through each lyrical section in sequence, offering genre-aware suggestions at each step.

```
GUIDED LYRICS COMPOSER FLOW
─────────────────────────────────────────────────────────────────
Step 1: INTRO
         ┌──────────────────────────────────────────────┐
         │  🌅 Intro                      [1 of 4]      │
         │  "Set the scene. Introduce the mood."        │
         │                                              │
         │  ┌────────────────────────────────────────┐  │
         │  │  Write your intro lines here...         │  │
         │  │                                        │  │
         │  └────────────────────────────────────────┘  │
         │                                              │
         │  ✦ Atmosphere for Amapiano Intro:           │
         │  [🥁 Deep log drum opening]                 │
         │  [🎹 Soft piano arpeggios]                  │
         │  [🌬️ Ambient wind texture]                  │
         │  [🎤 Soft spoken welcome line]              │
         │                                              │
         │  AI Suggestion: "Add a gentle fade-in with  │
         │  a single piano note to set the tone."      │
         │  [Apply Suggestion]  [Skip]                 │
         │                                              │
         │                    [Next: Verse 1 →]        │
         └──────────────────────────────────────────────┘

Step 2: VERSE 1  →  Step 3: CHORUS  →  Step 4: OUTRO
─────────────────────────────────────────────────────────────────
```

### Genre Atmosphere Library
Each genre has a curated library of atmosphere descriptors per section type:

```dart
// Embedded constant map — no network call needed
const kGenreAtmosphereLibrary = {
  'Amapiano': {
    LyricsSectionType.intro: [
      'Deep log drum opening',
      'Soft piano arpeggios',
      'Ambient township sound bed',
    ],
    LyricsSectionType.chorus: [
      'Call-and-response vocal hook',
      'Log drum build with brass stab',
      'Full choir backdrop',
    ],
    // ...
  },
  'Gqom': { ... },
  'Maskandi': { ... },
  // all 18 genres
};
```

### AI-Assisted Line Suggestions
For each section, the Guided Composer provides:
- **Grammar correction** — detects obvious errors and underlines with a yellow `~` indicator
- **Vocal improvement suggestion** — e.g., "This line could be a vocal run — try ending on a sustained vowel"
- **Frisson suggestions** — e.g., "Adding a pause before 'mehlo' will create tension"
- **Rhyme scheme hint** — shows what rhyme scheme the current section follows (ABAB, AABB, etc.)

### Lyrics Language Switcher
When the user has written lyrics in any Bantu language, a `BantuLanguageSwitcher` chip appears at the top of the section:

```
Language: [Tshivenḓa ✓] [isiZulu] [isiXhosa] [Sepedi] [Setswana] [siSwati]

When switching:
1. Show confirmation: "Translate all lyrics to isiZulu? This replaces current text."
2. Call BantuTranslationService.translate(text, fromLang, toLang)
3. Replace section lines with translated text
4. Mark section as translated with a 🌐 badge
```

---

## 8. Feature 5: Sample Deck Enhancement

### Current State
Bantu Voice Deck has 5 timbre cards. The Heritage Crate Browser and MPC Slicer are in a bottom sheet modal. There is no way to preview genre-specific drum patterns, percussion, or melodic motifs before committing to them.

### Target State: `GenreAtmosphereSampleDeck`
A new section in the `Compose` tab (below Genre selector, above Advanced Options) that presents **genre-specific sonic samples** grouped by instrument family:

```
┌──────────────────────────────────────────────────────────────┐
│  🥁 Sound Palette  [Amapiano]              [Browse All →]   │
│                                                              │
│  Drums & Percussion                                          │
│  [▶ Log Drum Deep]  [▶ Log Drum Light]  [▶ Shaker Loop]     │
│  [▶ Drum Snap]      [▶ Bass Kick 808]                       │
│                                                              │
│  Melodic Elements                                            │
│  [▶ Jazz Piano Chord]  [▶ Rhodes Melody]  [▶ Marimba Hook]  │
│                                                              │
│  Atmosphere                                                  │
│  [▶ Ambient Vocal Chop]  [▶ Township Ambient]               │
│                                                              │
│  ────────────────────────────────────────────────           │
│  🎵 Add Selected Samples to Generation Palette [+2]         │
└──────────────────────────────────────────────────────────────┘
```

Each sample is a 3-second clip (from the Heritage Crate or bundled assets) that the user can tap to preview before adding to their generation. This drastically reduces the "black box" feeling of Amapiano generation.

---

## 9. Feature 6: Kinetic Physics, Haptic Choreography & Micro-Interactions ("The Sensory Playground")

To elevate the Studio from a capable web-form into an irresistible, physical hardware-grade DAW & AI synthesizer, the cockpit incorporates a comprehensive **Kinetic Physics and Haptic Choreography System**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       STUDIO TACTILE SENSORY MATRIX                        │
├──────────────────────┬────────────────────────┬─────────────────────────────┤
│ Interaction          │ Physical Motion        │ Haptic Feedback             │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 🚀 Fire Generation   │ Button Scale 0.94      │ Heavy Impact (Thump)        │
│                      │ Spring back with Back  │ Double Pulse on Queued      │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 🎛️ Deck Tab Switch   │ Sliding Pill Indicator │ Medium Impact (Crisp Click) │
│                      │ 12px Parallax Fade     │                             │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 🎹 MPC / Sound Tap   │ Instant Depress        │ Heavy/Medium Impact         │
│                      │ Glowing Pad Ripple     │                             │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 🎚️ Sliders & Dials   │ Floating Spring Value  │ Selection Click             │
│                      │ Detent Snap Resistance │ (Every step tick)           │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 💡 AI Prompt Glow    │ Breathing Radial Aura  │ Light Impact on Complete    │
│                      │ Gradient Shimmer       │                             │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 🏷️ Option Chips      │ Micro Bouncy Scale     │ Selection Click             │
│                      │ (0.96 -> 1.0 Spring)   │                             │
├──────────────────────┼────────────────────────┼─────────────────────────────┤
│ 🔄 Session Restore   │ Banner Elastic Drop-in │ Medium Impact (Success)     │
└──────────────────────┴────────────────────────┴─────────────────────────────┘
```

### 9.1 The `StudioHaptics` Engine
A unified, resilient haptics dispatcher that wraps `HapticFeedback` with:
- **Platform Safety**: Silent no-op on Web (`kIsWeb`) or unhandled platforms without throwing exceptions.
- **Accessibility Respect**: Checks system reduced motion or vibration preferences (`MediaQuery.of(context).disableAnimations`).
- **Semantic Methods**: `ignitionThump()`, `deckSwitch()`, `sliderTick()`, `chipSnap()`, `successPulse()`.

### 9.2 `TactilePressable` (Elastic Micro-Interactions)
A universal micro-interaction wrapper widget applied to all interactive controls:
- **Physics**: Pointer down animates scale to `0.96` over 80ms (`Curves.easeInOut`). Pointer up/cancel springs back to `1.0` over 220ms using `Curves.easeOutBack` (slight playful overshoot).
- **Audio-Tactile Coupling**: Automatically fires the configured `StudioHaptics` trigger on tap down.
- **Zero Boilerplate**: Wraps any widget without interfering with layouts or hit test bounds.

### 9.3 Fluid Deck Switcher & Tab Transitions
Replaces the static tab switch with an **Elastic Tab Track**:
- Active tab pill uses an animated sliding pill with spring easing (`Curves.easeOutCubic`, 240ms).
- Content area features a smooth cross-fade with a subtle 8-12px horizontal directional slide.
- Switching between `Compose`, `Voice`, and `Crate & MPC` feels like sliding between physical synthesizer decks.

### 9.4 Dynamic Pulsing Aura & Kinetic Sliders
- **Aura**: The `PromptInputBox` and `PromptIntelligenceOverlay` are encircled by a gentle animated gradient aura (`AppColors.brandPrimary.withOpacity(0.25)`) that breathes rhythmically (1.5s sine cycle) while AI refinement or audio generation is active.
- **Kinetic Slider**: Sliders in `AdvancedOptionsAccordion` display a floating bubble indicator that springs above the thumb while dragged, emitting fine `selectionClick()` ticks at standard detents.

---

## 10. Verification Gates

| Gate | Command | Pass Criteria |
|---|---|---|
| Static analysis | `dart analyze lib test` | 0 issues |
| Studio provider tests | `flutter test test/features/studio/` | All pass |
| New session tests | `flutter test test/features/studio/session/` | All pass |
| Guided lyrics tests | `flutter test test/features/studio/lyrics/` | All pass |
| Tactile & haptics tests | `flutter test test/features/studio/tactile/` | All pass |
| Full regression | `flutter test` | ≥ 935 + new tests, 0 failures |

---

## 11. Design Constraints (Non-Negotiable)

1. **Zero regressions** on all existing `studioFormProvider`, `lyricsReviewProvider`, `generationPipelineProvider` test suites
2. **`IndexedStack` preserved** — 3-tab layout stays, new features slot into existing tabs
3. **`StudioFormState` API preserved** — only additive new fields (`sessionId`, `lastSavedAt`)
4. **Zero `build_runner`** — session repository uses hand-rolled JSON, untyped Hive box
5. **44×44px ergonomics** — all new option chips, guided composer controls, language switcher buttons
6. **No token violations** — zero raw hex, all colors from `AppColors`, all type from `AppTypography`
7. **DNA integration is read-only** — studio reads from `creatorDnaProvider` for pre-fill, never writes back directly (DNA writes happen via behavior events only)
8. **Platform-safe haptics** — all haptic invocations must degrade gracefully on Web and unsupported platforms with zero exceptions

