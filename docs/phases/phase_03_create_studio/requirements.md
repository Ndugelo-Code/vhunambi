# Phase 3 Requirements: Studio Creation Cockpit (`/create`)

> **Specification Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `MAY`)  
> **Traceability Root:** `REQ-STUDIO`

---

## 1. Top Navigation & Ingestion Requirements

- **REQ-STUDIO-01 (Top Bar Navigation):**
  - The Studio view **MUST** render a sticky top bar containing:
    - Back navigation button (triggering pop or navigation to index 0).
    - Vhunambi brand logo and wordmark.
    - Centered title `"Studio"`.
    - Token balance badge showing remaining generations (e.g. `⚡ 10 songs left`).
    - Notification bell trigger.
    - Direct link button to the user's Library.

- **REQ-STUDIO-02 (Prompt Input & Presets):**
  - The Studio view **MUST** provide a multiline text area accepting user song descriptions up to 1,000 characters.
  - The system **SHALL** provide at least 3 quick-tap inspiration preset chips that populate the prompt with authentic African musical scenarios.
  - The system **SHALL** provide an `✨ Inspire Me` button that populates a randomized seed prompt when pressed.

- **REQ-STUDIO-03 (Reference Audio Dropzone):**
  - The Studio view **MUST** provide a collapsible reference audio container supporting MP3, WAV, M4A, and FLAC files up to 50MB and 8 minutes.
  - When no audio file is selected, the UI **SHALL** show an upload icon, browse instruction, and technical format restrictions.
  - When an audio file is selected, the UI **SHALL** show the filename, file size, duration, and a clear button to remove the reference.

---

## 2. Genre & Multilingual Synthesis Requirements

- **REQ-STUDIO-04 (Regional Genre Selection):**
  - The Studio view **MUST** provide a regional segment control with at least: `South Africa`, `Africa`, `Americas`, `Global`, `Asia`.
  - The system **SHALL** render primary genre cards for the active region (at least: `Amapiano`, `Kwaito`, `Gqom`, `Maskandi`, `Mbaqanga`, `Marabi`, `Bubblegum`, `Afro House`).
  - The active genre **MUST** display a distinct border (`2px solid #F97316`) and update the form state immediately.
  - The system **SHALL** provide a custom genre text input allowing users to specify unlisted subgenres.

- **REQ-STUDIO-05 (African Multilingual Token Selection):**
  - The Studio view **MUST** support selection across at least 25 languages, with primary coverage of South African official languages (`Tshivenḓa`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sesotho sa Leboa`, `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `isiNdebele`) and major continental African languages (`Kiswahili`, `Hausa`, `Yorùbá`, `Igbo`, `Amharic`, `ChiShona`, `Lingála`, etc.).
  - Selecting a language chip **MUST** update the active language in the header and form state.

---

## 3. Advanced Parameters & Sonic Modulation Requirements

- **REQ-STUDIO-06 (Instrumental & Duration Controls):**
  - The Studio view **MUST** provide an `Instrumental only` switch that toggles lyric generation off.
  - The Studio view **MUST** provide a stepped slider supporting durations from 15s to 8 min (defaulting to 30s).

- **REQ-STUDIO-07 (Lyrics Mode):**
  - When instrumental is disabled, the system **MUST** offer 3 lyrics modes:
    1. `AI writes lyrics` (Default): Generates lyrics for user review prior to music synthesis.
    2. `My own lyrics`: Exposes a custom multiline editor for verse/chorus structure.
    3. `From photo`: Allows image upload for visual-to-lyric extraction.

- **REQ-STUDIO-08 (Sonic Modulation & Arrangements):**
  - The Studio view **MUST** provide 10 curated mood chips (`Uplifting`, `Melancholic`, `Romantic`, `Energetic`, `Peaceful`, `Angry`, `Nostalgic`, `Mysterious`, `Hopeful`, `Dark`).
  - The Studio view **MUST** provide 4 tempo bracket cards (`Slow <70`, `Medium 70-110`, `Fast 110-150`, `Very Fast 150+`).
  - The Studio view **MUST** provide arrangement selectors for:
    - Voices (`Solo`, `Duet`, `Choir`).
    - Gender (`Male`, `Female`, `Mixed`).
    - Mode (`Auto`, `Melodic`, `Rap`, `Spoken Word`, `Choir`).
    - Energy (`Soft`, `Mid`, `Intense`).
    - Song structure (`Standard`, `Extended`, `Freestyle`, `Loop`).

---

## 4. Submission & Action Deck Requirements

- **REQ-STUDIO-09 (Submission & Dynamic CTA):**
  - The Studio view **MUST** render a sticky action bar pinned to the bottom of the viewport.
  - The action bar **MUST** include a `Public` toggle switch controlling track visibility on the Explore feed.
  - When lyrics mode is `AI writes lyrics`, the primary CTA label **SHALL** read `"📄 Write Lyrics First"`.
  - When lyrics mode is `My own lyrics` or `Instrumental only`, the primary CTA label **SHALL** read `"✨ Generate Song"`.
  - Tapping the primary CTA **MUST** transition the generation state machine from `idle` to `generatingLyrics` or `queued`.

- **REQ-STUDIO-10 (Licensing & Terms Notice):**
  - The action bar **MUST** display the commercial ownership disclaimer: *"By generating, you agree to our Terms of Service. You own 100% of what you create on paid plans. See licensing ➔"*.
