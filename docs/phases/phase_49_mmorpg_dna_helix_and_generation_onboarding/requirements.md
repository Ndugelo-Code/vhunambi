# Phase 49 Requirements: MMORPG Creator DNA Helix & Generation-Aware Onboarding V2

## 1. Domain Glossary

- **SonicGenerationEra**: The cultural and chronological music era determined by the user's birth year (`1960–1989`: 80s Heritage Era; `1990–1999`: 90s Kwaito & House Era; `2000–2010`: 2000s Piano & Gqom Wave; `2011+`: Next-Gen Kinetic & Sgija Era).
- **CreatorDnaNode**: An individual genomic locus on the rotating 3D double-helix strand representing a sequenced trait or quest requirement.
- **GenomicStatus**: Lifecycle state of a DNA node: `sequenced` (active, unlocked during onboarding or via quest) or `lockedQuest` (inactive, displays quest instructions to unlock).
- **NodeInspectorCard**: An interactive detail bottom sheet or embedded card displaying the currently inspected genomic node's level, status badge, DNA power contribution (+15%), and quest instructions.
- **OpaqueCardFan**: A 3D stacked deck of cards where the frontmost card has a 100% opaque surface and background cards suppress their body text to prevent visual text bleed-through.
- **VignetteMask**: A radial gradient backdrop layer placed behind text elements that fades out background animated particles and orbits to ensure high contrast and WCAG AA legibility.

---

## 2. User Stories

1. **US-P49-01 (Legible Welcome Experience):** As an African creator opening Vhunambi, I want the kinetic backdrop particles to orbit smoothly without flying directly across the title and subtitle text, so that the opening screen is instantly readable and visually stunning.
2. **US-P49-02 (Clean Craft Tarot Selection):** As a producer or vocalist choosing my role, I want the active card in the 3D stack to be completely solid and clear, with only the top rims of background cards visible, so that multiple cards' text never overlaps into an unreadable ghost pile.
3. **US-P49-03 (Generation & Cultural Roots):** As an artist, I want to quickly dial in my birth year and see genres that shaped my generation automatically highlighted, so that I feel immediate cultural resonance without scrolling through redundant questionnaires.
4. **US-P49-04 (Interactive MMORPG DNA Helix):** As a creator in Act 4 and in the main app, I want to tap any node on my rotating 3D DNA strand to see what it does, how it tunes my sound, and what quests I can complete in the studio to level up my creative DNA.
5. **US-P49-05 (Seamless Studio & Profile Bridge):** As an active user on my profile or home dashboard, I want to access my full 3D DNA Lab at any time to inspect my unlocked powers and launch quests in the studio.

---

## 3. RFC 2119 Requirements

### Track A: Typography & Backdrop Staging (`REQ-P49-TYPO-##`)

1. **REQ-P49-TYPO-01**: `app_typography.dart` SHALL define `bouncyDisplayLarge` (28sp, `FontWeight.w900`, letterSpacing: `-0.6`), `bouncyTitleLarge` (22sp, `FontWeight.w800`, letterSpacing: `-0.4`), and `bouncyBadge` (11sp, `FontWeight.w800`, letterSpacing: `0.2`) utilizing GoogleFonts Outfit or Plus Jakarta Sans with a system font fallback.
2. **REQ-P49-TYPO-02**: Onboarding Act 1 title and subtitle SHALL employ bouncy display typography wrapped in an elastic entrance curve (`Curves.easeOutBack`).
3. **REQ-P49-TYPO-03**: `onboarding_procedural_canvas.dart` SHALL restrict primary orbiting constellation nodes to the vertical band $Y \in [0.18 \times \text{height}, 0.38 \times \text{height}]$ centered around the Vhunambi crest.
4. **REQ-P49-TYPO-04**: `onboarding_procedural_canvas.dart` SHALL render a soft radial legibility vignette centered behind the typography zone with minimum opacity 0.45.

---

### Track B: 3D Card Fan Bleed Eradication (`REQ-P49-CARD-##`)

1. **REQ-P49-CARD-01**: In `interactive_identity_card_stack.dart`, the active card (`relativeDepth == 0`) SHALL render with a 100% opaque background surface (`AppColors.surfaceElevatedOf(context)` with `alpha: 1.0`).
2. **REQ-P49-CARD-02**: Background cards (`relativeDepth > 0`) SHALL hide all inner titles, descriptions, badges, and waveforms by setting their body content opacity to `0.0`.
3. **REQ-P49-CARD-03**: Background cards SHALL render with an upward vertical offset `translateY = -relativeDepth * 14.0dp` and scale `1.0 - relativeDepth * 0.055`, presenting a clean fan of colored top rims.
4. **REQ-P49-CARD-04**: `InteractiveIdentityCardStack` SHALL provide explicit horizontal navigation buttons (`Key('identity_stack_prev_btn')` and `Key('identity_stack_next_btn')`) alongside direct card tap-to-select and horizontal drag gestures.
5. **REQ-P49-CARD-05**: Flipping cards SHALL trigger haptic feedback (`HapticFeedback.selectionClick()`).

---

### Track C: Generation-Aware Roots Deck (`REQ-P49-ROOTS-##`)

1. **REQ-P49-ROOTS-01**: `OnboardingState` and `CreatorDnaProfile` SHALL include `int birthYear` (default `2002`, range `1960..2018`), `SonicGenerationEra generationEra`, and `String culturalHeritage`.
2. **REQ-P49-ROOTS-02**: `SonicGenerationEra.fromBirthYear(int year)` SHALL evaluate:
   - `1960..1989` $\rightarrow$ `SonicGenerationEra.era80sGolden`
   - `1990..1999` $\rightarrow$ `SonicGenerationEra.era90sKwaitoHouse`
   - `2000..2010` $\rightarrow$ `SonicGenerationEra.era2000sPianoGqom`
   - `2011..2026+` $\rightarrow$ `SonicGenerationEra.era2011NextGenKinetic`
3. **REQ-P49-ROOTS-03**: `SonicGenerationEra` SHALL provide `recommendedGenres` mapped to authentic regional musical traditions.
4. **REQ-P49-ROOTS-04**: Act 3 SHALL eliminate the legacy 4-box `Vibe Energy & Tempo Feel` section and fit entirely within a single viewport without vertical scroll bars.
5. **REQ-P49-ROOTS-05**: Act 3 SHALL display an interactive Birth Year Dial (`Key('onboarding_birth_year_selector')`) displaying a live Era badge and a 1-tap `"Auto-Tune Genres for My Era"` action.
6. **REQ-P49-ROOTS-06**: Genre cards matching the user's `generationEra` SHALL render a glowing `"✨ Era Match"` tag.

---

### Track D: MMORPG 3D DNA Helix & Node Inspector (`REQ-P49-DNA-##` & `REQ-P49-LAB-##`)

1. **REQ-P49-DNA-01**: The Creator DNA helix SHALL model 8 discrete genomic loci (`CreatorDnaNode`):
   - Node 1: `craft_persona` (Friendly persona title, e.g. `'Kinetic Creator & Curator'`)
   - Node 2: `generation_era` (`'Born $birthYear • ${era.label}'`)
   - Node 3: `linguistic_roots` (`'${languages.join(" • ")}'`)
   - Node 4: `sonic_genres` (`'${genres.join(" • ")}'`)
   - Node 5: `voice_signature` (Quest: *"Record a 20s voice take in Studio to sequence your vocal timbre."*)
   - Node 6: `groove_architect` (Quest: *"Build a 5-channel log-drum groove in Sketchpad."*)
   - Node 7: `co_creation_lineage` (Quest: *"Drop an Open-Verse or Stem-Flip on Explore."*)
   - Node 8: `ar_tastemaker` (Quest: *"Co-sign emerging artists in the Fresh Crate."*)
2. **REQ-P49-DNA-02**: In Act 4, Nodes 1–4 SHALL display `GenomicStatus.sequenced` and Nodes 5–8 SHALL display `GenomicStatus.lockedQuest`.
3. **REQ-P49-DNA-03**: Tapping any node on the 3D double-helix (via raycast hit-testing within $28\text{dp}$) or tapping any node pill (`Key('dna_helix_node_$index')`) SHALL rotate the helix to face that node, draw a pulsating target ring around it, and open `dna_node_inspector_card`.
4. **REQ-P49-DNA-04**: `dna_node_inspector_card` SHALL display Node Name, Level/Status Badge (`🟢 SEQUENCED LVL 1` vs `🔒 LOCKED QUEST NODE`), DNA Power (+15%), detailed description, and quest action button.
5. **REQ-P49-DNA-05**: In Act 4 and throughout the UI, `CreativeRole` SHALL ALWAYS render as a friendly title (e.g. `'Kinetic Creator & Curator'`) and NEVER as raw enum string `'MUSICLOVER'` (`STD-UIUX-001`).
6. **REQ-P49-LAB-01**: `CreatorDnaProfileCard` (used on `OwnerProfileView`, `ArtistProfileView`, and `HomeDashboardView`) SHALL embed a live interactive 3D Mini-Helix and a `[ 🧬 Open 3D DNA Lab ]` button (`Key('open_3d_dna_lab_btn')`).
7. **REQ-P49-LAB-02**: Tapping `open_3d_dna_lab_btn` SHALL present `CreatorDnaHelixLabSheet` in modal full-screen allowing free 3D rotation, node inspection, and 1-tap quest navigation (`[ Complete Quest in Studio → ]`).

---

### Track E: Non-Negotiable Invariants (`REQ-P49-INV-##`)

1. **REQ-P49-INV-01**: Zero new plugins in `pubspec.yaml`.
2. **REQ-P49-INV-02**: `dart analyze lib test` MUST report **`0 issues found!`** (Zero errors, zero warnings, zero hints).
3. **REQ-P49-INV-03**: All widget tests in `test/features/onboarding/` and `test/features/profile/` MUST be **100% green**.
4. **REQ-P49-INV-04**: Minimum 44×44dp touch targets on all interactive controls.
5. **REQ-P49-INV-05**: Preserves backward compatibility with all Phase 44–48 edge sync and video fixes.

---

## 4. Traceability Matrix

| Requirement ID | Description | Design Component | Implementation Task | Verification Test |
|---|---|---|---|---|
| `REQ-P49-TYPO-01..04` | Bouncy typography & safe backdrop orbit bounds | `app_typography.dart`, `onboarding_procedural_canvas.dart` | T1.1, T1.2 | `phase49_mmorpg_dna_and_generation_onboarding_test.dart` (Test 1) |
| `REQ-P49-CARD-01..05` | 100% opaque front card & background text hiding | `interactive_identity_card_stack.dart` | T2.1, T2.2 | `phase49_mmorpg_dna_and_generation_onboarding_test.dart` (Test 2) |
| `REQ-P49-ROOTS-01..06` | Birth year dial, era mapping & era-recommended genres | `onboarding_models.dart`, `onboarding_act3_roots_deck.dart` | T3.1..T3.4 | `phase49_mmorpg_dna_and_generation_onboarding_test.dart` (Test 3) |
| `REQ-P49-DNA-01..05` | 8-node MMORPG Genomic model & node inspector | `creator_dna_node.dart`, `creator_dna_helix_finale.dart` | T4.1..T4.3 | `phase49_mmorpg_dna_and_generation_onboarding_test.dart` (Test 4) |
| `REQ-P49-LAB-01..02` | Main app 3D DNA Lab modal sheet & `open_3d_dna_lab_btn` | `creator_dna_profile_card.dart`, `creator_dna_helix_lab_sheet.dart` | T4.4, T4.5 | `phase49_mmorpg_dna_and_generation_onboarding_test.dart` (Test 5) |
| `REQ-P49-INV-01..05` | Zero plugins, clean analyze, 100% green tests | Core architecture | T5.1..T5.3 | `dart analyze` & `flutter test` |

