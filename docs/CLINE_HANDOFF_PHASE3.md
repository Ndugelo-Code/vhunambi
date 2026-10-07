# Master Handoff Prompt: Phase 3 — Studio Creation Cockpit (`/create`)

> **To be executed by:** Cline (DeepSeek V4 Flash / 1M Context Window)  
> **Working Directory:** `apps/vhunambi_client/`  
> **Source Blueprint:** `docs/foundation_blueprints/03_CREATE_STUDIO_SPEC.md`  
> **Phase 4-Doc Suite:** `docs/phases/phase_03_create_studio/` (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`)  
> **Architecture Standard:** `docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`

---

## Pre-Flight Status & Guardrails
- **Current Baseline:** `flutter analyze` reports `0 issues`. `flutter test` reports all tests passing.
- **Brand Identity:** Name is strictly `vhunambi` (with an **i**).
- **Design Tokens:** Strictly utilize `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` from `package:vhunambi_client/core/theme/`. **Never hardcode raw hex values or ad-hoc border radii.**
- **Enums & Types:** Do not import `RepeatMode` from Flutter; our audio repeat enum is `AudioRepeatMode`.

---

## Phase 3 Implementation Goal
Build out the complete, parameter-rich **Studio Creation Cockpit (`StudioView`)** under `lib/features/studio/` based on Blueprint 03, and wire it into the `Create` tab (index 2) of `RootShell` in `lib/main.dart`.

---

## Step-by-Step Task Sequence

### 1. Create Domain State Models
Path: `lib/features/studio/domain/models/studio_form_state.dart`
- Enums: `LyricsMode` (`aiWrite`, `myOwn`, `fromPhoto`, `instrumental`), `TempoBracket` (`slow`, `medium`, `fast`, `veryFast`), `VocalVoices` (`solo`, `duet`, `choir`), `VocalGender` (`male`, `female`, `mixed`), `VocalMode` (`auto`, `melodic`, `rap`, `spokenWord`, `choir`), `VocalEnergy` (`soft`, `mid`, `intense`), `SongStructure` (`standard`, `extended`, `freestyle`, `loop`), `GenerationPhase` (`idle`, `generatingLyrics`, `reviewingLyrics`, `queued`, `processing`, `ready`, `failed`).
- Immutable `StudioFormState` class matching Section 4.1 of Blueprint 03 with default values (`genre: 'Amapiano'`, `region: 'South Africa'`, `language: 'English'`, `durationSeconds: 30`, `mood: 'Uplifting'`, `tempo: TempoBracket.medium`).

### 2. Create Riverpod State Notifier
Path: `lib/features/studio/presentation/providers/studio_form_provider.dart`
- `final studioFormProvider = StateNotifierProvider<StudioFormNotifier, StudioFormState>((ref) => StudioFormNotifier());`
- Methods: `updatePrompt`, `setGenre`, `setRegion`, `setLanguage`, `toggleInstrumental`, `setDurationSeconds`, `setLyricsMode`, `setCustomLyrics`, `setMood`, `setTempo`, `setVocalVoices`, `setVocalGender`, `setVocalMode`, `setVocalEnergy`, `setSongStructure`, `toggleAutoTitle`, `setCustomTitle`, `togglePublic`, `applyPromptPreset(String preset)`.

### 3. Create Studio UI Components
Path: `lib/features/studio/presentation/widgets/`
- **`prompt_input_box.dart`**:
  - Multiline TextField (`12px` radius, background `#141418`, focus border `#F97316`).
  - 3 quick prompt preset chips (`"A heartbreak track about leavin..."`, `"Late-night log drum session, da..."`, `"Township love story — two peo..."`).
  - Outlined pill button `✨ Inspire Me` populating a random scenario.
- **`reference_audio_dropzone.dart`**:
  - Collapsible accordion with dashed border container (`1.5px dashed #4B4B5A`, `#141418` surface).
  - Upload tray icon, `"Drop audio file here or click to browse"`, and subtext `"MP3, WAV, M4A, FLAC — max 50MB, up to 8 min"`.
- **`regional_genre_selector.dart`**:
  - Search pill: `"Search genres (e.g. Ama, Hip...)"`.
  - Regional segment rail: `South Africa` (active `#F97316`), `Africa`, `Americas`, `Global`, `Asia`.
  - 8 primary genre tiles: `Amapiano`, `Kwaito`, `Gqom`, `Maskandi`, `Mbaqanga`, `Marabi`, `Bubblegum`, `Afro House` (with active 2px `#F97316` border and subtle orange glow).
  - Custom genre input row with `+ Add a genre not in the list...` + `Add` button.
- **`multilingual_language_selector.dart`**:
  - Active language badge indicator.
  - Multi-select language chips across 25+ South African, continental African, and diaspora languages (`Tshivenḓa`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sesotho sa Leboa`, `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `isiNdebele`, `Kiswahili`, `Hausa`, `Yorùbá`, `Igbo`, `አማርኛ`, `Soomaali`, `ChiShona`, `Luganda`, `Kinyarwanda`, `Lingála`, `Wolof`, `Twi`, `Français`, `Português`, `العربية`, `Español`, `Hindi`).
- **`advanced_options_accordion.dart`**:
  - `Instrumental only` switch toggle.
  - `Song length` stepped slider (`15s`, `30s`, `1 min`, `2 min`, `4 min`, `6 min`, `8 min`).
  - Lyrics 3-way mode switch (`✨ AI writes lyrics`, `✍️ My own lyrics`, `📷 From photo`).
  - 10 Mood chips (`😊 Uplifting`, `🌧️ Melancholic`, `💕 Romantic`, `⚡ Energetic`, `🕊️ Peaceful`, `🔥 Angry`, `📻 Nostalgic`, `🌙 Mysterious`, `✨ Hopeful`, `🖤 Dark`).
  - 4 Tempo bracket cards (`Slow < 70`, `Medium 70-110`, `Fast 110-150`, `Very Fast 150+`).
  - Vocal controls: Voices (`Solo`, `Duet`, `Choir`), Gender (`Male`, `Female`, `Mixed`), Mode (`Auto`, `Melodic`, `Rap`, `Spoken Word`, `Choir`), Energy (`Soft`, `Mid`, `Intense`).
  - Song structure (`Standard`, `Extended`, `Freestyle`, `Loop`) and Title setting (`AI picks title` vs `I'll name it`).
- **`studio_action_bar.dart`**:
  - Visibility card: Public toggle switch (`"Visible on Explore & your profile"`).
  - Primary full-width `#F97316` button: `📄 Write Lyrics First` (or `✨ Generate Song` if instrumental).
  - Commercial licensing note: *"By generating, you agree to our Terms of Service. You own 100% of what you create on paid plans. See licensing ➔"*.

### 4. Create StudioView & Wire into RootShell
- Path: `lib/features/studio/presentation/views/studio_view.dart`
  - Sticky `StudioAppBar` with brand mark, `"Studio"` title, `⚡ 10 songs left` badge, notification bell, and `Library` link.
  - Scrollable body composing all sections above.
- In `lib/main.dart`:
  - Replace `const Scaffold(body: Center(child: Text('Create Studio')))` in `_pages[2]` with `const StudioView()`.

---

## Verification & Quality Thresholds
1. Run `flutter analyze` inside `apps/vhunambi_client`. Must report `No issues found!`.
2. Run `flutter test` inside `apps/vhunambi_client`. All tests must pass cleanly.
