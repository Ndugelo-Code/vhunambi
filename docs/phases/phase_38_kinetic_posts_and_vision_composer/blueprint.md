# Phase 38 Blueprint: Kinetic Posts System & Non-Invasive Sonic Feed Experience

**Document Version:** 1.0.0  
**Status:** Approved for Implementation  
**Predecessor:** Phase 37 (Participatory Open-Verse & Stem-Flip Chains)  
**Applicability:** `apps/vhunambi_client` (Explore Feed & Social Domain) & `apps/vhunambi_api`  

---

## 1. Executive Summary & Problem Space

On the `/explore` feed, the current social music post card (`ExploreSocialPostCard`) renders as a rigid template: text caption above a bulky rectangular MP3 box with an orange border. This presents several major UX and architectural limitations:
1. **Vertical Screen Theft & Overflow Clipping:** The oversized rectangular MP3 player block consumes over 50% of card height and clips vertically on compact mobile screens (as seen on physical device recordings).
2. **Missing Creator Media Controls:** Creators cannot upload static photos, generate bespoke visual artwork via Vhunambi Vision AI, select custom aspect ratios (`1:1 Square`, `4:5 Portrait`, `16:9 Landscape`), or trim audio snippet windows (15s, 30s, 60s, Full).
3. **Absence of a Feed Composer Bar:** While the top of Explore has a "Post Reel" button for 9:16 vertical video, there is no quick-composer entry point to author an editorial feed post.
4. **Blurry Media Boundaries:** Without a strict protocol, feed cards risk duplicating video logic from full-screen 9:16 Kinetic Reels (`KineticReelsModal`).

Phase 38 solves these challenges by establishing a strict architectural separation between **Kinetic Reels** and **Kinetic Posts**, introducing the **Non-Invasive Frosted Sonic Pill**, and providing creators with a rich **CreateKineticPostSheet** equipped with Vhunambi Vision AI image generation and universal vault audio trimming.

---

## 2. The Strict Media Boundary: Kinetic Reels vs. Kinetic Posts

| Dimension | Kinetic Reel (9:16 Immersive) | Kinetic Post (Editorial & Decorative Feed Card) |
| :--- | :--- | :--- |
| **Primary Surface** | Full-screen vertical swipe session (`KineticReelsModal`). | Natural scrolling feed card on `/explore`. |
| **Visual Media** | 9:16 kinetic typography / vertical loop. | Static Images Only (1–4) via Phone Upload or Vhunambi Vision AI (`1:1`, `4:5`, `16:9`), or Text + Audio. **Strictly NO .mp4/.mov video files (`REQ-KPOST-NO-MP4`).** |
| **Audio UI Pattern**| Full-screen audio pool. | **Non-Invasive Sonic Pill (`KineticPostSonicPill`)**: 40dp frosted glass overlay on images, or 44dp slim capsule bar when text-only. Tapping Play immediately routes to global `playerStateProvider` / Mini-Player. |
| **Audio Attachments**| Published song clip. | Universal Vault: Songs (`libraryTracksProvider`), Beats (`beatsProvider`), Voice DNA (`soundSignatureProvider`), or Grooves (`melodySketchpadProvider`) with customizable snippet duration (15s / 30s / 60s / Full). |
| **Repost Sovereignty**| N/A | Reposters can quote or share, but the attached audio, trim bounds, and artwork are **100% immutable and locked to the original creator**. |

---

## 3. Four-Zone Editorial Card Hierarchy

```
┌────────────────────────────────────────────────────────────────────────────┐
│ 1. CREATOR IDENTITY HEADER (48dp)                                          │
│ [Avatar] Creator Display Name ✔️ · @handle · 2h · Location   [+ Follow] [⋯]│
├────────────────────────────────────────────────────────────────────────────┤
│ 2. CLEAN EDITORIAL CAPTION (#Hashtags & @Mentions + Expandable "…more")    │
│ Late night studio session testing Venda Folk LoRA & sub-bass slide.        │
│ Stems are open for remix! #Amapiano #Tshivenda                             │
├────────────────────────────────────────────────────────────────────────────┤
│ 3. VISUAL CANVAS (Creator Resizable: 4:5 Portrait | 1:1 Square | 16:9 Wide)│
│ ┌────────────────────────────────────────────────────────────────────────┐ │
│ │                                                                        │ │
│ │               [ Phone Photo OR Vhunambi Vision AI Artwork ]            │ │
│ │                                                                        │ │
│ │   ┌──────────────────────────────────────────────────────────────────┐ │ │
│ │   │ (▶) Track Title · Amapiano · 0:30 Hook      ▂▄▆█▃▅ (112 BPM)   │ │ │
│ │   └──────────────────────────────────────────────────────────────────┘ │ │
│ │    ▲ NON-INVASIVE FROSTED SONIC PILL (Triggers Mini-Player on Tap!)    │ │
│ └────────────────────────────────────────────────────────────────────────┘ │
│ *(When Post has NO image, Sonic Pill renders as a slim 44dp capsule bar)*  │
├────────────────────────────────────────────────────────────────────────────┤
│ 4. SOCIAL & CO-CREATION ACTION BAR (44dp Touch Targets)                    │
│   ♡ Like (1.8K)   💬 Comment (96)   🔁 Repost (12)   🎛️ Remix   🪙 Tip   ↗️  │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Track Breakdown

- **Track A:** `KineticPost` Domain Models, Strict No-MP4 Guard & Repost Sovereignty (`SocialMusicPost` evolution).
- **Track B:** Redesigned `ExploreSocialPostCard` with Resizable Visuals & Non-Invasive Frosted Sonic Pill (`KineticPostSonicPill`).
- **Track C:** "Create Kinetic Post" Composer Bar & Authoring Workstation Sheet (`KineticPostComposerBar` & `CreateKineticPostSheet`).
- **Track D:** Verification Test Suites, Analyzer Cleanliness & Hardware Deployment.

