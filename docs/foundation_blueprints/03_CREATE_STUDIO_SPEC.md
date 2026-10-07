# Blueprint 03: Create Studio Cockpit Specification (`03_CREATE_STUDIO_SPEC.md`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS)  
> **Route Path:** `/create` / Studio Cockpit  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Studio (`https://vhunambi.com/studio` / `/create`)

---

## 1. Studio Architecture & Visual Scaffolding

The Studio Cockpit is Vhunambi's audio synthesis engine. Unlike generic text-to-music prompts, Vhunambi provides a specialized, parameter-rich workstation tailored specifically for African vocal nuances, regional BPM structures, multi-dialect lyricism, and stem/reference conditioning.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [ < ]  (🎵) VHUNAMBI          Studio               [⚡ 10 songs left]  [🔔]  [📚] │ <-- Top Bar
└──────────────────────────────────────────────────────────────────────────────────┘
│                                                                                  │
│ ✨ Describe your song                                                            │
│ ┌──────────────────────────────────────────────────────────────────────────────┐ │
│ │ A powerful anthem about rising from hardship, full of hope and energy...     │ │
│ └──────────────────────────────────────────────────────────────────────────────┘ │
│ [ A heartbreak track... ]  [ Late-night log drum... ]  [ Township love... ]      │
│ [ ✨ Inspire Me ]                                                                │
│                                                                                  │
│ ⮟ Reference Audio (optional)                                                     │
│ ⮟ Genre  [ Amapiano ]                                                            │
│ ⮟ Language  [ English ]                                                          │
│ ⮟ Advanced Options                                                               │
│                                                                                  │
│ [ 🌐 Public (Visible on Explore & profile)                             ( ● ) ]  │
│ ┌──────────────────────────────────────────────────────────────────────────────┐ │
│ │                           📄 Write Lyrics First                              │ │ <-- Sticky Action CTA
│ └──────────────────────────────────────────────────────────────────────────────┘ │
│         AI writes the lyrics ➔ you review & edit ➔ then the beat is produced      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Sticky Studio Navigation Bar (`StudioAppBar`)
* **Height:** `64px` desktop / `56px` mobile + top safe area.
* **Surface:** `#0A0A0C` with 1px bottom border `#2D2D38`.
* **Components (Left to Right):**
  1. **Back Navigation:** Icon button `Icons.arrow_back_ios_new_rounded` (`size: 16`, `#FFFFFF`).
  2. **Brand Emblem:** Circular amber pill with musical note icon + bold wordmark `"VHUNAMBI"` (`#FFFFFF`).
  3. **Route Title:** Centered `"Studio"` (`fontSize: 16`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  4. **Credit Balance Badge:** Pill container (`#1B1B22`, border `1px solid #2D2D38`, padding `6px 12px`):
     * Icon: `⚡` / `Icons.bolt_rounded` (`color: #F97316`).
     * Label: `"10 songs left"` (`fontSize: 13`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  5. **Notification Bell:** Icon button `Icons.notifications_none_rounded` (`size: 20`, `#9CA3AF`).
  6. **Library Quick-Link:** Pill button with book/music icon + label `"Library"` (`#1B1B22` background).

---

### 1.2 Top Input Cockpit (Prompt & Inspiration)

* **Section Header:** `Icons.auto_awesome` / sparkle (`#F97316`) + `"Describe your song"` (`fontSize: 16`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
* **Prompt Text Area:**
  * Background: `#141418` (`surfaceElevated`), border `1px solid #2D2D38`, focus border `#F97316`.
  * Corner Radius: `12px` (`AppRadius.input`).
  * Min Lines: `4`, Max Lines: `8`.
  * Placeholder: `"A powerful anthem about rising from hardship, full of hope and energy..."` (`color: #6B7280`).
* **Quick Inspiration Prompt Chips:**
  * Horizontal scrolling pill rail of curated thematic presets:
    * `"A heartbreak track about leavin..."`
    * `"Late-night log drum session, da..."`
    * `"Township love story — two peo..."`
  * Styling: Background `#1B1B22`, border `1px solid #2D2D38`, text `#9CA3AF` (`fontSize: 12`), hover `#FFFFFF`.
* **`✨ Inspire Me` Action Button:**
  * Outlined pill button with sparkle icon (`#1B1B22` background, border `1px solid #2D2D38`, text `#FFFFFF`, `fontSize: 13`).
  * Action: Populates prompt text area with a random culturally rich seed scenario.

---

### 1.3 Audio Reference Dropzone (`Reference Audio (optional)`)

Collapsible accordion enabling audio-to-audio style transfer, melody reference, or remixing:

```
┌────────────────────────────────────────────────────────────────────────┐
│ ⮝ Reference Audio (optional)                                           │
│ Upload a song to use as a melody reference, remix source, or style     │
│ inspiration. The AI will generate a new song influenced by your track. │
│                                                                        │
│ ┌ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -┐ │
│ │                           [ ⭡ Upload ]                             │ │
│ │              Drop audio file here or click to browse               │ │
│ │             MP3, WAV, M4A, FLAC — max 50MB, up to 8 min            │ │
│ └ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -┘ │
└────────────────────────────────────────────────────────────────────────┘
```

* **Header:** `Icons.file_upload_outlined` + `"Reference Audio (optional)"` + Chevron indicator.
* **Instruction Text:** `"Upload a song to use as a melody reference, remix source, or style inspiration. The AI will generate a new song influenced by your reference track."` (`fontSize: 13`, `#9CA3AF`).
* **Drop Target Container:**
  * Border: `1.5px dashed #4B4B5A`, border-radius `12px`.
  * Background: `#141418` (`surfaceElevated`).
  * Centered Icon: `Icons.file_upload_rounded` (`size: 32`, `#9CA3AF`).
  * Primary Text: `"Drop audio file here or click to browse"` (`fontSize: 14`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  * Sub-text: `"MP3, WAV, M4A, FLAC — max 50MB, up to 8 min"` (`fontSize: 12`, `#6B7280`).
  * Drag & Drop States: Highlights border in `#F97316` on drag-over.

---

## 2. Parameter Extraction & Control Groups

### 2.1 Regional Genre & Sub-Genre Selector

Collapsible accordion with active selection chip indicator in header (`Genre: [ Amapiano ]`):

```
┌────────────────────────────────────────────────────────────────────────┐
│ ⮝ Genre  [ Amapiano ]                                                  │
│                                                                        │
│ [ 🔍 Search genres (e.g. Ama, Hip...)                                ] │
│                                                                        │
│ [ South Africa ]  [ Africa ]  [ Americas ]  [ Global ]  [ Asia ]       │
│                                                                        │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│ │ 🎹 Amapiano  │  │  💿 Kwaito   │  │   💥 Gqom    │  │ 🎸 Maskandi  │ │
│ └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│ │ 🪕 Mbaqanga  │  │  🎹 Marabi   │  │ 🍬 Bubblegum │  │ 🥁 Afro House│ │
│ └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                                        │
│ [ + Add a genre not in the list...                           ] [ Add ] │
└────────────────────────────────────────────────────────────────────────┘
```

* **Search Filter:** Search pill (`height: 38px`, background `#141418`, border `#2D2D38`, hint: `"Search genres (e.g. Ama, Hip...)"`).
* **Regional Segment Rail:**
  * `South Africa` (Active: `#F97316` background, `#000000` text).
  * `Africa`, `Americas`, `Global`, `Asia` (Inactive: Transparent/dark, `#9CA3AF` text).
* **Primary Genre Tiles (2 to 4 Column Grid):**
  * Aspect ratio `1.2:1` card, background `#1B1B22`, border-radius `12px`.
  * **Active State:** Highlighted border `2px solid #F97316`, subtle orange glow.
  * **Tile Content:** Centered vector icon/emoji + bold genre label.
  * **Core Roster:**
    1. `Amapiano` (Piano keyboard / log drum)
    2. `Kwaito` (Cassette / vinyl record)
    3. `Gqom` (Neon spark / bass pulse)
    4. `Maskandi` (Acoustic folk guitar)
    5. `Mbaqanga` (Brass / traditional bass)
    6. `Marabi` (Upright shebeen piano)
    7. `Bubblegum` (80s synthesizer / cassette)
    8. `Afro House` (Tribal drum / shaker)
* **Custom Genre Adder:**
  * Input row: TextField hint `"+ Add a genre not in the list..."` + solid `#1B1B22` button `"Add"`.

---

### 2.2 African Multilingual Token Selector

Collapsible accordion with active language badge (`Language: [ English ]`):

```
┌────────────────────────────────────────────────────────────────────────┐
│ ⮝ Language  [ English ]                                                │
│                                                                        │
│ [ isiZulu ]  [ isiXhosa ]  [ Afrikaans ]  [ English ]  [ Sesotho sa L ] │
│ [ Setswana ] [ Sesotho ]   [ Xitsonga ]   [ siSwati ]  [ Tshivenḓa ]   │
│ [ isiNdebele ]                                                         │
│                                                                        │
│ [ Kiswahili ][ Hausa ]     [ Yorùbá ]     [ Igbo ]     [ አማርኛ ]       │
│ [ Soomaali ] [ ChiShona ]  [ Luganda ]    [ Kinyarwanda] [ Lingála ]   │
│ [ Wolof ]    [ Twi ]       [ Français ]   [ Português ][ العربية ]    │
│ [ Español ]  [ Hindi ]                                                 │
└────────────────────────────────────────────────────────────────────────┘
```

* **Active Chip:** Background `#F97316`, Text `#000000`, `fontWeight: FontWeight.bold`.
* **Inactive Chip:** Background `#1B1B22`, border `1px solid #2D2D38`, text `#9CA3AF`, hover `#FFFFFF`.
* **Complete Linguistic Classification (25+ Languages):**
  * **South African Official:**
    * `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sesotho sa Leboa` (Sepedi), `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `Tshivenḓa`, `isiNdebele`.
  * **Continental African:**
    * `Kiswahili` (East Africa), `Hausa` (West Africa), `Yorùbá` (Nigeria/Benin), `Igbo` (Nigeria), `አማርኛ` / Amharic (Ethiopia), `Soomaali` (Somalia), `ChiShona` (Zimbabwe), `Luganda` (Uganda), `Kinyarwanda` (Rwanda), `Lingála` (Congo DRC), `Wolof` (Senegal), `Twi` (Ghana).
  * **Diaspora & Global Languages:**
    * `Français`, `Português`, `العربية` (Arabic), `Español`, `Hindi`.

---

### 2.3 Advanced Options Accordion

```
┌────────────────────────────────────────────────────────────────────────┐
│ ⮝ Advanced Options                                                     │
│                                                                        │
│ [ 🎚️ Instrumental only ]                             (  Off  ) [ ● ]  │
│ Skip lyrics — generate music only                                      │
│                                                                        │
│ ⏱️ Song length                                                    30s   │
│ ──●─────────────────────────────────────────────────────────────────── │
│ 15s           2 min           4 min           6 min           8 min    │
│                                                                        │
│ ✍️ Lyrics                                                              │
│ [ ✨ AI writes lyrics ]      [ ✍️ My own lyrics ]      [ 📷 From photo ] │
│ ⓘ AI will generate lyrics and show them to you to review and edit      │
│   before producing the beat.                                           │
└────────────────────────────────────────────────────────────────────────┘
```

#### 1. Instrumental Only Toggle
* Leading: `Icons.music_note_outlined` + Title `"Instrumental only"`.
* Subtitle: `"Skip lyrics — generate music only"` (`fontSize: 12`, `#9CA3AF`).
* Control: Orange switch toggle (`activeColor: #F97316`).

#### 2. Song Length Stepped Slider
* Header: `Icons.timer_outlined` + `"Song length"` with live value indicator pill on the right: `"30s"`, `"2 min"`, `"4 min"`.
* Track Range: `15s` $\rightarrow$ `2 min` $\rightarrow$ `4 min` $\rightarrow$ `6 min` $\rightarrow$ `8 min`.
* Step Markers: Distinct tick dots along the slider track.

#### 3. Lyrics Mode Switcher (3-Way Segmented Control)
* Segment Options:
  1. `✨ AI writes lyrics` (Active: `#F97316`, pure black text).
  2. `✍️ My own lyrics` (Opens custom verse/chorus editor text field with syllable counts).
  3. `📷 From photo` (Invokes multimodal image upload to extract themes/objects into lyrics).
* Helper Banner:
  * Background: `#1B1B22` with subtle information badge (`#22D3EE`).
  * Text: *"AI will generate lyrics and show them to you to review and edit before producing the beat."*

---

### 2.4 Sonic Modulation Selectors

#### 1. Mood Selection (10 Curated Sentiment Chips)
Multi-row wrap of sentiment chips with accompanying emojis:
* `😊 Uplifting`
* `🌧️ Melancholic`
* `💕 Romantic`
* `⚡ Energetic`
* `🕊️ Peaceful`
* `🔥 Angry`
* `📻 Nostalgic`
* `🌙 Mysterious`
* `✨ Hopeful`
* `🖤 Dark`

#### 2. Tempo Rail (4 BPM Bracket Cards)
4-column card grid selecting rhythmic tempo:

| Label | BPM Range | Typical African Genre Application |
| :--- | :--- | :--- |
| **Slow** | `< 70 BPM` | Soul, Afro Jazz, Traditional Acoustic Maskandi |
| **Medium** | `70 - 110 BPM` | Standard Amapiano (112-115), Afrobeats, Mbaqanga |
| **Fast** | `110 - 150 BPM` | Fast Amapiano, Afro House, Marabi, Kwaito |
| **Very Fast** | `150+ BPM` | Gqom, Kuduro, Shangaan Electro |

#### 3. Vocal Arrangement Controls

```
┌────────────────────────────────────────────────────────────────────────┐
│ 👥 Voices                                                              │
│ [ 🎤 Solo (Single voice) ]   [ 👥 Duet (Two voices) ]   [ 🏛️ Choir ]    │
│                                                                        │
│ 👤 Vocal Gender                                                        │
│ [ ♂ Male ]               [ ♀ Female ]               [ ⚥ Mixed ]        │
│                                                                        │
│ 🎙️ Vocal Mode                                                          │
│ [ ⚡ Auto ]   [ 🎵 Melodic ]   [ 🎤 Rap ]   [ 🗣️ Spoken ]  [ 👥 Choir ] │
│                                                                        │
│ ⚡ Vocal Energy                                                        │
│ [ 🌙 Soft (Gentle) ]     [ ☀️ Mid (Balanced) ]     [ 🔥 Intense ]      │
└────────────────────────────────────────────────────────────────────────┘
```

* **Voices:**
  * `Solo` (Single voice)
  * `Duet` (Two voices)
  * `Choir` (Group harmonies)
* **Vocal Gender:**
  * `Male` (`Icons.male_rounded`)
  * `Female` (`Icons.female_rounded`)
  * `Mixed` (`Icons.transgender_rounded` / group icon)
* **Vocal Mode:**
  * `Auto` (AI decides best stylistic vocal style based on genre)
  * `Melodic` (Sung vocal melody)
  * `Rap` (Rhythmic delivery / township vernacular flow)
  * `Spoken Word` (Poetic, theatrical spoken delivery)
  * `Choir` (Layered call-and-response group chorus)
* **Vocal Energy:**
  * `Soft` (Gentle, breathy, intimate)
  * `Mid` (Balanced, melodic)
  * `Intense` (Powerful belts, raspy, stadium chants)

#### 4. Song Architecture & Title Setting
* **Song Structure:**
  * `Standard` (Verse-chorus-bridge)
  * `Extended` (Long DJ mix intro & outro for club play)
  * `Freestyle` (Continuous through-composed melody, no fixed repeats)
  * `Loop` (Seamless DJ-friendly loop)
* **Song Title Mode:**
  * `✨ AI picks title` (Active: `#F97316` pill)
  * `✍️ I'll name it` (Reveals title input field)

---

## 3. Submission Deck & Sticky Action Bar

```
┌────────────────────────────────────────────────────────────────────────┐
│ [ 🌐 Public (Visible on Explore & your profile)               ( ● ) ]  │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │                       📄 Write Lyrics First                        │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│       AI writes the lyrics ➔ you review & edit ➔ then the beat is produced    │
│  By generating, you agree to our Terms of Service. You own 100% of what you   │
│                   create on paid plans. See licensing ➔                │
└────────────────────────────────────────────────────────────────────────┘
```

* **Visibility Switch Card:**
  * Container: `#141418`, border `1px solid #2D2D38`, border-radius `12px`, padding `12px 16px`.
  * Leading: Globe icon `Icons.public_rounded` (`#F97316`).
  * Text Column: Title `"Public"`, subtitle `"Visible on Explore & your profile"`.
  * Toggle: Cupertino/Material switch (`activeColor: #F97316`).
* **Primary Action CTA (`Write Lyrics First` / `Generate Song`):**
  * Height: `52px`, full-width pill button (`BorderRadius.circular(9999)`).
  * Color: Solid `#F97316` (`brandPrimary`), pressed state `#EA580C`.
  * Content: Leading document icon + bold label `"Write Lyrics First"` (`color: #000000`, `fontSize: 16`).
  * Conditional Label:
    * When lyrics mode is `AI writes lyrics`: `"Write Lyrics First"`.
    * When lyrics mode is `My own lyrics` or `Instrumental only`: `"Generate Song"`.
* **Legal Disclaimer & Licensing:**
  * Text: *"By generating, you agree to our Terms of Service. You own 100% of what you create on paid plans. See licensing ➔"* (`fontSize: 11`, `color: #6B7280`).

---

## 4. State Management Architecture & Generation Payload

```
┌───────────────────────────────────────────────────────────────┐
│                       StudioView (UI)                         │
└───────────────────────────────┬───────────────────────────────┘
                                │ ref.watch(studioFormNotifier)
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                    StudioFormNotifier                         │
│  - updatePrompt(String)         - setGenre(String)            │
│  - setLanguage(String)          - setMood(String)             │
│  - setLyricsMode(LyricsMode)    - toggleInstrumental(bool)    │
│  - submitGeneration()           - uploadReferenceAudio(File)  │
└───────────────────────────────┬───────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                   Generation Lifecycle FSM                    │
│   [idle] ➔ [generating_lyrics] ➔ [reviewing_lyrics] ➔          │
│   [queued_inference] ➔ [processing_audio] ➔ [ready / failed]  │
└───────────────────────────────────────────────────────────────┘
```

### 4.1 Immutable Generation Form State Model

```dart
// lib/features/studio/domain/models/studio_form_state.dart
import 'package:flutter/foundation.dart';

enum LyricsMode { aiWrite, myOwn, fromPhoto, instrumental }
enum TempoBracket { slow, medium, fast, veryFast }
enum VocalVoices { solo, duet, choir }
enum VocalGender { male, female, mixed }
enum VocalMode { auto, melodic, rap, spokenWord, choir }
enum VocalEnergy { soft, mid, intense }
enum SongStructure { standard, extended, freestyle, loop }
enum GenerationPhase { idle, generatingLyrics, reviewingLyrics, queued, processing, ready, failed }

@immutable
class StudioFormState {
  final String prompt;
  final String? referenceAudioPath;
  final String genre;
  final String region;
  final String language;
  final bool isInstrumental;
  final int durationSeconds;
  final LyricsMode lyricsMode;
  final String? customLyrics;
  final String mood;
  final TempoBracket tempo;
  final VocalVoices vocalVoices;
  final VocalGender vocalGender;
  final VocalMode vocalMode;
  final VocalEnergy vocalEnergy;
  final SongStructure songStructure;
  final bool isAutoTitle;
  final String? customTitle;
  final bool isPublic;
  final GenerationPhase phase;
  final double generationProgress;
  final String? errorMessage;

  const StudioFormState({
    this.prompt = '',
    this.referenceAudioPath,
    this.genre = 'Amapiano',
    this.region = 'South Africa',
    this.language = 'English',
    this.isInstrumental = false,
    this.durationSeconds = 30,
    this.lyricsMode = LyricsMode.aiWrite,
    this.customLyrics,
    this.mood = 'Uplifting',
    this.tempo = TempoBracket.medium,
    this.vocalVoices = VocalVoices.solo,
    this.vocalGender = VocalGender.male,
    this.vocalMode = VocalMode.auto,
    this.vocalEnergy = VocalEnergy.mid,
    this.songStructure = SongStructure.standard,
    this.isAutoTitle = true,
    this.customTitle,
    this.isPublic = true,
    this.phase = GenerationPhase.idle,
    this.generationProgress = 0.0,
    this.errorMessage,
  });

  StudioFormState copyWith({
    String? prompt,
    String? referenceAudioPath,
    String? genre,
    String? region,
    String? language,
    bool? isInstrumental,
    int? durationSeconds,
    LyricsMode? lyricsMode,
    String? customLyrics,
    String? mood,
    TempoBracket? tempo,
    VocalVoices? vocalVoices,
    VocalGender? vocalGender,
    VocalMode? vocalMode,
    VocalEnergy? vocalEnergy,
    SongStructure? songStructure,
    bool? isAutoTitle,
    String? customTitle,
    bool? isPublic,
    GenerationPhase? phase,
    double? generationProgress,
    String? errorMessage,
  }) {
    return StudioFormState(
      prompt: prompt ?? this.prompt,
      referenceAudioPath: referenceAudioPath ?? this.referenceAudioPath,
      genre: genre ?? this.genre,
      region: region ?? this.region,
      language: language ?? this.language,
      isInstrumental: isInstrumental ?? this.isInstrumental,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lyricsMode: lyricsMode ?? this.lyricsMode,
      customLyrics: customLyrics ?? this.customLyrics,
      mood: mood ?? this.mood,
      tempo: tempo ?? this.tempo,
      vocalVoices: vocalVoices ?? this.vocalVoices,
      vocalGender: vocalGender ?? this.vocalGender,
      vocalMode: vocalMode ?? this.vocalMode,
      vocalEnergy: vocalEnergy ?? this.vocalEnergy,
      songStructure: songStructure ?? this.songStructure,
      isAutoTitle: isAutoTitle ?? this.isAutoTitle,
      customTitle: customTitle ?? this.customTitle,
      isPublic: isPublic ?? this.isPublic,
      phase: phase ?? this.phase,
      generationProgress: generationProgress ?? this.generationProgress,
      errorMessage: errorMessage,
    );
  }
}
```

---

### 4.2 Backend Worker API Generation Payload Contract

Matches the RunPod/ZR Studio audio synthesis inference pipeline:

```json
{
  "prompt": "A powerful anthem about rising from hardship, full of hope and energy...",
  "reference_audio_url": "https://storage.vhunambi.com/refs/user_ref_923.mp3",
  "genre": "Amapiano",
  "region": "South Africa",
  "language": "Tshivenḓa",
  "is_instrumental": false,
  "duration_seconds": 90,
  "lyrics": {
    "mode": "ai_write",
    "content": null,
    "source_photo_url": null
  },
  "sonic_parameters": {
    "mood": "Uplifting",
    "tempo_bpm_bracket": "medium",
    "vocal_voices": "solo",
    "vocal_gender": "male",
    "vocal_mode": "melodic",
    "vocal_energy": "mid",
    "song_structure": "standard"
  },
  "metadata": {
    "auto_title": true,
    "custom_title": null,
    "is_public": true
  }
}
```
