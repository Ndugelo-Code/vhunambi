# Phase 39 Blueprint: Sovereign Creator Identity, 3-Stage Discovery Hierarchy & Multi-Talent Marketplace

**Document Version:** 1.0.0  
**Status:** Approved for Implementation  
**Predecessor:** Phase 38 (Kinetic Posts Architecture & Vhunambi Vision Image Composer)  
**Applicability:** `apps/vhunambi_client` (Profile, Explore, Studio, Marketplace) & `apps/vhunambi_api`  

---

## 1. Executive Summary & Problem Space

With Phase 38 live on hardware, Vhunambi provides 60 FPS full-screen Kinetic Reels and editorial Kinetic Posts with docked frosted Sonic Pills. However, as the ecosystem scales beyond prompt-based creation, four critical architectural gaps emerge:
1. **Homogeneous Creator Identity:** Traditional FL Studio/Ableton producers, natural acapella singers, Maskandi/Jazz live instrumentalists, and stage dancers are currently grouped into a generic "creator" bucket without distinct identity or provenance.
2. **Missing Direct DAW / Audio Uploader:** Musicians producing in external DAWs or natural singers recording acapellas have no dedicated uploader to import `.wav`/`.mp3` masters or stems into Vhunambi without passing through the AI generation loop.
3. **Explore Quality Degradation & Garbage Dump Trap:** If every raw AI generation or unfinished snippet is dumped onto `/explore`, the feed quickly degrades into an uncurated landfill. A structured 3-stage discovery hierarchy is required to rank high-completion, co-created, and authentic music on Mainstage while nurturing emerging talent in Rising Breakout and Fresh Crate.
4. **Single-Pillar Beat Market:** The `/market` surface is strictly locked to instrumental beats, locking out natural singers selling vocal hooks, instrumentalists licensing guitar/sax stems, and creators offering trained Voice DNA packs.

Phase 39 eliminates these boundaries by establishing:
- **5 Sovereign Creator Identity Archetypes & Audio Provenance Badges**.
- **The Direct DAW & Natural Vocal/Stem Uploader Workstation**.
- **A 3-Stage Discovery Hierarchy Ranking Engine (`DiscoveryHierarchyRanker`)**.
- **The 4-Pillar Multi-Talent & Stem Marketplace (Beats, Vocals, Live Instruments, Voice DNA)** with unified 85% ZAR royalties and instant Vault bridging.

---

## 2. Five Sovereign Creator Identity Archetypes

To celebrate the multi-faceted genius of African music, every creator declares their Sovereign Archetype:

| Archetype | Identifier | Core Craft | Primary Tools |
| :--- | :--- | :--- | :--- |
| **DAW Producer** | `dawProducer` | Beatmaker, Mixing & Mastering Engineer | FL Studio, Ableton Live, Logic Pro, Cubase |
| **Natural Vocalist** | `naturalVocalist` | Acapella Singer, Lyricist, Choral/Chant Artist | Natural Voice, Condenser Mic, Audio Uploader |
| **Live Instrumentalist** | `liveInstrumentalist` | Guitarist, Saxophonist, Bassist, Percussionist | Live Acoustic/Electric Instruments, Stems |
| **Kinetic Performer** | `kineticPerformer` | Stage Dancer, Choreographer, Hype Vocalist | Camera Performance Reels, 9:16 Kinetic Video |
| **AI Sonic Architect** | `aiSonicArchitect` | Prompt Engineer, LoRA Trainer, Hybridizer | Vhunambi Generative Engine, Sketchpad, LoRAs |

Every profile displays the creator's Sovereign Archetype badge alongside their **Monthly Listeners** pill (e.g., `14.2K Monthly Listeners`).

---

## 3. Audio Provenance Hierarchy

Every audio asset on Vhunambi carries an immutable `AudioProvenanceType` token:

```
┌────────────────────────────────────────────────────────────────────────┐
│ AUDIO PROVENANCE ENGINE                                                │
│                                                                        │
│ 🎛️ Human DAW Master      (100% Human Audio from external DAW)         │
│ 🎙️ 100% Live Vocal       (Pure human voice recording / acapella)      │
│ 🎸 Live Instrument Stem  (Real guitar, sax, brass, percussion stem)    │
│ 🔀 Hybrid Co-Creation    (Human live layer + AI groove / stem-flip)    │
│ ✨ Vhunambi AI           (AI generative model output)                  │
└────────────────────────────────────────────────────────────────────────┘
```

The Provenance Badge is prominently rendered on `ExploreSocialPostCard`, `KineticPostSonicPill`, and `TrackCard` to ensure 100% transparency and pride of human craft.

---

## 4. Direct DAW & Vocal Uploader (`DirectDawVocalUploadSheet`)

A dedicated modal sheet launched from `OwnerProfileView` and `StudioView` (`Key('open_daw_vocal_uploader_btn')`) offering 3 distinct authoring flows:
- **Flow 1 (`Upload DAW Master / Stems`):** Traditional musicians drag & drop or pick `.wav`/`.mp3` masters and stems, specify title, genre, BPM, key, and tag as `AudioProvenanceType.humanDawMaster`.
- **Flow 2 (`Record / Upload Natural Vocal or Live Instrument`):** Natural singers and instrumentalists record or upload acapellas or guitar/sax stems, tagging as `liveVocalRecording` or `liveInstrumentStem`. They can publish directly to Explore or list as an asset on `/market` for 85% royalties!
- **Flow 3 (`Camera Performance Reel`):** Dancers and performers launch the performance video recorder to publish directly to `KineticReelsModal`.

---

## 5. Three-Stage Scalable Discovery Hierarchy

To keep `/explore` prestigious, inspiring, and clean from low-effort spam, the `DiscoveryHierarchyRanker` classifies posts into 3 distinct tiers:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. MAINSTAGE (Top 10% Velocity, Co-Creation Pull & High Completion)   │
│    High-retention hits, viral stem remixes, verified artist releases  │
├────────────────────────────────────────────────────────────────────────┤
│ 2. RISING BREAKOUT (Trending New Grooves & Fast-Climbing Creators)    │
│    Active remix activity, rapid follower conversion, strong playback   │
├────────────────────────────────────────────────────────────────────────┤
│ 3. FRESH CRATE (New Community Uploads, Vocal Takes & Raw Grooves)     │
│    Community incubator, open verse invitations, raw acapellas          │
└────────────────────────────────────────────────────────────────────────┘
```

### Discovery Rank Score Formula:
$$\text{Score} = (0.30 \times \text{CompletionVelocity}) + (0.25 \times \text{RemixPull}) + (0.20 \times \text{CreatorInfluence}) + (0.15 \times \text{GraphBoost}) + (0.10 \times \text{CraftBonus})$$

Raw uncurated generations remain private in the user's Library Vault until explicitly published.

---

## 6. Four-Pillar Multi-Talent Marketplace (`/market`)

The marketplace expands from beats only to the full African creator economy:
1. **Beats & Instrumentals (`beats`):** Full productions and backing tracks.
2. **Vocal Hooks & Acapellas (`vocals`):** Live Tshivenḓa, isiZulu, Sesotho, Xhosa, and English hooks for producers.
3. **Live Guitars, Sax & Loops (`liveInstruments`):** Maskandi acoustic guitar riffs, Pretoria Amapiano sax solos, log drum loops.
4. **Voice DNA & Sound Packs (`voiceDnaAndPacks`):** Registered Voice Signature DNA (`VHU-SIG`) and genre sound kits.

All purchases automatically split **85% net royalties to the creator** in ZAR/Coins and bridge the licensed asset directly into the buyer's Library Vault for instant use in Studio, Sketchpad, or Kinetic Posts.

