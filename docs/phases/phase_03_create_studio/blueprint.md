# Phase 3 Blueprint: Studio Creation Cockpit (`/create`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Cross-Platform)  
> **Route Path:** `/create` (Mounted in Tab Index 2 of `RootShell`)  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Studio (`https://vhunambi.com/studio` / `/create`)

---

## 1. Visual Architecture & Layout Geometry

The Studio Cockpit is Vhunambi's audio synthesis engine. Unlike generic text-to-music prompts, Vhunambi provides a specialized, parameter-rich workstation tailored specifically for African vocal nuances, regional BPM structures, multi-dialect lyricism, and stem/reference conditioning.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [ < ]  (🎵) VHUNAMBI          Studio               [⚡ 10 songs left]  [🔔]  [📚] │ <-- Top Bar (64px/56px)
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

### 1.1 Responsive Breakpoints
* **Mobile (< 768px):**
  - Single-column vertical scroll.
  - Sticky bottom action bar padded above the persistent mini-player.
  - Genre selector in 2-column grid.
  - Multilingual chips in auto-wrapping flex row.
* **Desktop / Web (> 1024px):**
  - Centered max-width container (`840px` max width) with generous padding (`AppSpacing.xl`).
  - Genre selector in 4-column grid.
  - Fixed sticky bottom action bar within container bounds.

---

## 2. Core Visual Components & Parameter Groups

### 2.1 Sticky Top Bar (`StudioAppBar`)
* **Height:** `64px` on desktop, `56px` on mobile.
* **Background:** `AppColors.surfaceCanvas` (`#0A0A0C`) with bottom border `AppColors.borderSubtle` (`#2D2D38`).
* **Leading:** Back icon button + circular amber logo mark `"VHUNAMBI"`.
* **Center:** Title `"Studio"` (`AppTypography.titleMedium`, `#FFFFFF`).
* **Trailing:**
  - Token badge: `⚡ 10 songs left` (`AppColors.surfaceSecondary`, orange bolt icon).
  - Notification bell button.
  - Library link button.

### 2.2 Top Input Cockpit (`PromptInputBox`)
* **Section Title:** `Icons.auto_awesome` sparkle (`AppColors.brandPrimary`) + `"Describe your song"`.
* **Multiline Input:** 4–8 lines, `AppColors.surfaceElevated` (`#141418`), `AppRadius.inputBorder` (12px), orange focus border.
* **Quick Inspiration Rail:** Horizontal pill rail with 3 presets:
  1. `"A heartbreak track about leavin..."`
  2. `"Late-night log drum session, da..."`
  3. `"Township love story — two peo..."`
* **Inspiration Trigger:** `✨ Inspire Me` outlined pill populating random scenarios.

### 2.3 Audio Reference Dropzone (`ReferenceAudioDropzone`)
* Collapsible accordion for audio-to-audio style transfer, remixing, or melody conditioning.
* Dashed border container: `1.5px dashed #4B4B5A`, border-radius 12px, surface `#141418`.
* Instruction: `"Upload a song to use as a melody reference, remix source, or style inspiration. The AI will generate a new song influenced by your reference track."`
* Drop target: Upload icon, `"Drop audio file here or click to browse"`, subtext `"MP3, WAV, M4A, FLAC — max 50MB, up to 8 min"`.

### 2.4 Regional Genre Selector (`RegionalGenreSelector`)
* Header with active badge: `Genre: [ Amapiano ]`.
* Search pill: `"Search genres (e.g. Ama, Hip...)"`.
* Regional tabs: `South Africa` (Active: `#F97316`), `Africa`, `Americas`, `Global`, `Asia`.
* Primary genre tiles (2 to 4 columns):
  `Amapiano`, `Kwaito`, `Gqom`, `Maskandi`, `Mbaqanga`, `Marabi`, `Bubblegum`, `Afro House`.
  - Active state: Highlighted `2px solid #F97316` with subtle orange glow.
* Custom genre adder input row.

### 2.5 Multilingual Selector (`MultilingualLanguageSelector`)
* Header with active badge: `Language: [ English ]`.
* 25+ Indigenous & Continental African dialects + Global languages:
  - SA Official: `Tshivenḓa`, `isiZulu`, `isiXhosa`, `Afrikaans`, `English`, `Sesotho sa Leboa`, `Setswana`, `Sesotho`, `Xitsonga`, `siSwati`, `isiNdebele`.
  - Continental: `Kiswahili`, `Hausa`, `Yorùbá`, `Igbo`, `አማርኛ`, `Soomaali`, `ChiShona`, `Luganda`, `Kinyarwanda`, `Lingála`, `Wolof`, `Twi`.
  - Diaspora/Global: `Français`, `Português`, `العربية`, `Español`, `Hindi`.

### 2.6 Advanced Sonic Options (`AdvancedOptionsAccordion`)
* **Instrumental Only:** Switch toggle (`activeColor: #F97316`).
* **Song Length:** Stepped slider with 5 milestones (`15s`, `2 min`, `4 min`, `6 min`, `8 min`).
* **Lyrics Mode:** 3-way segment (`✨ AI writes lyrics`, `✍️ My own lyrics`, `📷 From photo`).
* **Mood:** 10 sentiment chips (`😊 Uplifting`, `🌧️ Melancholic`, `💕 Romantic`, `⚡ Energetic`, `🕊️ Peaceful`, `🔥 Angry`, `📻 Nostalgic`, `🌙 Mysterious`, `✨ Hopeful`, `🖤 Dark`).
* **Tempo Bracket:** 4 BPM cards (`Slow <70`, `Medium 70-110`, `Fast 110-150`, `Very Fast 150+`).
* **Vocal Controls:**
  - Voices: `Solo`, `Duet`, `Choir`
  - Gender: `Male`, `Female`, `Mixed`
  - Mode: `Auto`, `Melodic`, `Rap`, `Spoken Word`, `Choir`
  - Energy: `Soft`, `Mid`, `Intense`
* **Song Structure:** `Standard`, `Extended`, `Freestyle`, `Loop`.
* **Song Title Mode:** `✨ AI picks title` vs `✍️ I'll name it`.

### 2.7 Sticky Submission Deck (`StudioActionBar`)
* Public toggle card: `"Visible on Explore & your profile"`.
* Main Action CTA:
  - If AI lyrics: `"📄 Write Lyrics First"`
  - If instrumental / custom lyrics: `"✨ Generate Song"`
  - Full-width pill button, solid `AppColors.brandPrimary` (`#F97316`), black text.
* Commercial licensing note: `"By generating, you agree to our Terms of Service. You own 100% of what you create on paid plans. See licensing ➔"`.

---

## 3. Audio Synthesis State Machine

```
[idle]
  │
  ├─(AI lyrics)──► [generatingLyrics] ──► [reviewingLyrics] ──┐
  │                                                            ▼
  └─(Instrumental / Custom)───────────────────────────────► [queued]
                                                               │
                                                               ▼
                                                          [processing]
                                                               │
                                                    ┌──────────┴──────────┐
                                                    ▼                     ▼
                                                 [ready]               [failed]
```
