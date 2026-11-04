# Phase 37 Technical Design: Open-Verse Challenges, Stem-Flip Chains & Co-Creation Royalties

**Document Version:** 1.0.0  
**Status:** Approved  

---

## 1. Domain Models & Data Structures

### 1.1 `RemixCreationMode` Enum
```dart
enum RemixCreationMode {
  openVerseVocal, // Vocalist dropped a verse over parent beat
  beatStemFlip,   // Producer flipped the groove/log-drum
  aiStudioRemix,  // Full studio synthesis with parent conditioning
}
```

### 1.2 Lineage Metadata on `PublishedClip` & `SocialMusicPost`
```dart
class PublishedClip {
  // Existing fields...
  final RemixCreationMode? remixMode;
  final String? parentClipId;
  final String? parentTrackTitle;
  final String? parentCreatorId;
  final String? parentCreatorHandle;
  final int remixGenerationDepth; // 0 for root, 1 for child, etc.
  final int remixChildrenCount;
  final List<SplitParticipant> coCreationSplits;
}
```

---

## 2. Audio DSP & Mixdown Design (`StemMixBounceService`)

### 2.1 44.1 kHz 16-Bit Stereo Summing Algorithm
```
Input:
  1. Backing PCM bytes (44.1 kHz 16-bit Stereo) from MelodyWavSynthesizer
  2. Vocal PCM bytes (44.1 kHz 16-bit Mono or Stereo) from SoundSignatureResynthesizer
  3. StemMixerState gains: g_drums, g_bass, g_melody, g_vocals, and pan laws
  4. MasterBusDsp params: tubeDrive, ceiling = -1.0 dBFS

Processing Loop (per sample pair L, R):
  S_inst_L, S_inst_R = backing_samples * inst_gain
  S_voc_L, S_voc_R   = vocal_samples * voc_gain
  
  // Summing
  Mix_L = S_inst_L + S_voc_L
  Mix_R = S_inst_R + S_voc_R
  
  // Tube Saturation Drive (soft rational tanh approximation)
  Mix_L = rationalTanh(Mix_L * drive)
  Mix_R = rationalTanh(Mix_R * drive)
  
  // Peak Limiter (-1.0 dBFS = 0.8912 max peak)
  Mix_L = clamp(Mix_L, -29200, 29200)
  Mix_R = clamp(Mix_R, -29200, 29200)
  
Output:
  44-byte RIFF/WAVE header + clamped 16-bit signed PCM byte buffer
```

---

## 3. UI Component Architecture

### 3.1 `OpenVerseRemixCockpitSheet`
- Curvy `Container` with `AppRadius.modalBorder` and `AppColors.surfaceModal`.
- Animated mode tabs:
  - `Key('remix_cockpit_mode_verse')`: Drop Open Verse.
  - `Key('remix_cockpit_mode_flip')`: Flip Beat & Log-Drum.
  - `Key('remix_cockpit_mode_studio')`: Full Studio Handoff.
- Interactive controls:
  - `Key('remix_record_verse_btn')`: Count-in + live record.
  - `Key('remix_audition_mix_btn')`: A/B play mix.
  - `Key('remix_publish_btn')`: One-tap bounce & publish.

### 3.2 `RemixLineageTreeSheet`
- Tree visualization using custom painter or stacked nodes.
- Root node: Parent track (`@makhadzi`).
- Child nodes: Branching remixes with avatar, badge, genre, and play button.
- Bottom CTA: `"Drop Your Verse on This Chain"`.

### 3.3 `ActiveRemixLineageBanner`
- Mounted at top of `StudioView`.
- Displays parent track title, creator handle, locked BPM/Key, and `Key('studio_clear_remix_btn')`.

