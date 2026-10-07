# Phase 3 Tasks & Verification Plan: Studio Creation Cockpit (`/create`)

> **Status:** ✅ Complete — 100% Implemented, Analyzed & Verified  
> **Target:** `apps/vhunambi_client`  
> **Parent Spec:** `docs/phases/phase_03_create_studio/`

---

## 1. Pre-Flight Codebase Anchors

- [x] Baseline verification: `dart analyze .` reports `0 issues`.
- [x] Brand verification: App name is strictly `vhunambi`.
- [x] Token verification: `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` available in `package:vhunambi_client/core/theme/`.
- [x] Enum safety: Verify no conflicts with `RepeatMode` (use `AudioRepeatMode`).

---

## 2. Sequenced Implementation Tasks

- [x] **Task 3.1: Domain State Models**
  - Path: `lib/features/studio/domain/models/studio_form_state.dart`
  - Implemented enums: `LyricsMode`, `TempoBracket`, `VocalVoices`, `VocalGender`, `VocalMode`, `VocalEnergy`, `SongStructure`, `GenerationPhase`.
  - Implemented immutable `StudioFormState` class with `copyWith`, `==`, and `hashCode`.

- [x] **Task 3.2: Riverpod State Notifier**
  - Path: `lib/features/studio/presentation/providers/studio_form_provider.dart`
  - Implemented `StudioFormNotifier` and exported `studioFormProvider`.
  - Implemented mutating methods for all form attributes, seed presets, `inspireMe()`, and generation state transitions.

- [x] **Task 3.3: Ingestion & Dropzone Widgets**
  - Path: `lib/features/studio/presentation/widgets/prompt_input_box.dart`
    - Multiline text field with focus styling and synchronization.
    - Preset inspiration chips and `✨ Inspire Me` action button.
  - Path: `lib/features/studio/presentation/widgets/reference_audio_dropzone.dart`
    - Collapsible container with dashed border and audio upload triggers.

- [x] **Task 3.4: Genre & Multilingual Selectors**
  - Path: `lib/features/studio/presentation/widgets/regional_genre_selector.dart`
    - Regional segment tabs (`South Africa`, `Africa`, etc.).
    - 8 core genre tiles with active `#F97316` 2px border and glow.
    - Custom genre adder row.
  - Path: `lib/features/studio/presentation/widgets/multilingual_language_selector.dart`
    - Multi-chip rail with 25+ African and diaspora languages.

- [x] **Task 3.5: Advanced Options & Action Deck**
  - Path: `lib/features/studio/presentation/widgets/advanced_options_accordion.dart`
    - Instrumental switch, song length slider (15s to 8min), 3-way lyrics mode.
    - 10 mood chips, 4 tempo bracket cards, vocal arrangement selectors, and song structure.
  - Path: `lib/features/studio/presentation/widgets/studio_action_bar.dart`
    - Public visibility toggle card.
    - Primary full-width CTA (`Write Lyrics First` / `Generate Song`).
    - Commercial licensing disclaimer.

- [x] **Task 3.6: Screen Assembly & RootShell Integration**
  - Path: `lib/features/studio/presentation/views/studio_view.dart`
    - Sticky `StudioAppBar` with credit counter badge (`⚡ 10 left`) and notification bell.
    - Composed all widgets into a responsive layout (max-width `840px` on desktop).
  - Modified `lib/main.dart` to mount `StudioView` in tab index 2 of `RootShell`.

- [x] **Task 3.7: Automated Tests**
  - Unit tests: `test/features/studio/studio_form_test.dart` (11 passing tests).
  - Widget tests: `test/features/studio/studio_view_test.dart` (2 passing tests).
  - Smoke tests: `test/widget_test.dart` (1 passing test).

---

## 3. Verification Commands & Gate Thresholds

```powershell
# 1. Static Analysis Gate
cd apps/vhunambi_client
dart analyze .

# 2. Automated Test Verification
flutter test
```

### Thresholds & Outcomes
- `dart analyze .`: **0 issues found!**
- `flutter test`: **14 of 14 tests passing cleanly (100%)!**
