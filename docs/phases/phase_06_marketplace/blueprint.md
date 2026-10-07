# Phase 6 Blueprint: Beats Marketplace & Marketing Funnel (`/market` & `/`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Cross-Platform)  
> **Route Paths:** `/market` (Beats Marketplace, Tab Index 4 of `RootShell`) & `/` (Home Marketing Funnel, Tab Index 0 of `RootShell`)  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com/market` & `https://vhunambi.com`)  
> **Parent Blueprint:** [`docs/foundation_blueprints/05_MARKETPLACE_AND_LANDING_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/05_MARKETPLACE_AND_LANDING_SPEC.md)

---

## 1. Executive Vision & Scope

Phase 6 implements the two remaining primary views within Vhunambi's 5-tab root shell:
1. **The Beats Marketplace (`/market`, Tab Index 4):** A commercial beat licensing exchange allowing music creators and producers to audition, license, and download African instrumental productions (Amapiano, Gqom, Maskandi, Afro House) using platform credits.
2. **The Marketing Landing Funnel (`/`, Tab Index 0):** The primary homepage showcasing African musical heritage, interactive sample audio, 20+ regional genres, 6 core value pillars, cultural translation spotlight, creator testimonials, and 4 subscription pricing tiers.

---

## 2. Beats Marketplace Scaffolding (`/market`)

### 2.1 Visual Architecture & Layout Geometry

```
Desktop Marketplace Scaffolding (> 1024px):
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [ < ] (🎵) VHUNAMBI          [ 🔍 Search beats or producers... ]          [⚡ 10 songs] [🔔] [👤]│
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 🛍️ Beats Marketplace                                                                [ 🎛 Filters ]│
│ License African beats from top producers — pay in credits, download instantly                    │
│                                                                                                  │
│ ┌──────────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ (🪙) Sell your beats                                                         [Go to Library] │ │ <-- Amber Glow
│ │ Create instrumental beats and list them here. Every time someone licenses your               │ │     Monetization
│ │ beat, credits go straight to your balance.                                                   │ │     Banner
│ └──────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                                  │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                           │
│ │ [112 BPM] [F#]│  │ [128 BPM] [Am]│  │ [115 BPM] [C] │  │ [120 BPM] [Gm]│                           │
│ │    (▶) 🎹    │  │    (▶) 🥁    │  │    (▶) 🎸    │  │    (▶) 🎵    │  <-- 4-Column Grid        │
│ ├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤      (Desktop)            │
│ │ Township Heat│  │ Durban Night │  │ Zulu Acoustic│  │ Sunset Groove│                           │
│ │ @sipho_beats │  │ @djvibe      │  │ @ndugelo     │  │ @lerato_prod │                           │
│ │ ⚡ 5 Credits  │  │ ⚡ 5 Credits  │  │ ⚡ 5 Credits  │  │ ⚡ 5 Credits  │                           │
│ │[License Beat]│  │[License Beat]│  │[License Beat]│  │[License Beat]│                           │
│ └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘                           │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

```
Mobile Marketplace Viewport (< 768px):
┌────────────────────────────────────────────────────────────────────────┐
│ [ < ] (🎵)  [ 🔍 Search beats...                                ] [🔔] │
├────────────────────────────────────────────────────────────────────────┤
│ 🛍️ Beats Marketplace                                     [ 🎛 Filters ] │
│ License African beats from top producers — pay in credits              │
│                                                                        │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │ (🪙) Sell your beats                             [Go to Library]   │ │
│ │ Create instrumental beats and list them here.                      │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│ ┌──────────────────────────┐  ┌──────────────────────────┐             │
│ │ [112 BPM]           [F#] │  │ [128 BPM]           [Am] │             │
│ │          (▶) 🎹          │  │          (▶) 🥁          │             │
│ ├──────────────────────────┤  ├──────────────────────────┤             │
│ │ Township Heat            │  │ Durban Night             │             │
│ │ @sipho_beats             │  │ @djvibe                  │             │
│ │ ⚡ 5 Credits   [License] │  │ ⚡ 5 Credits   [License] │             │
│ └──────────────────────────┘  └──────────────────────────┘             │
│                                                                        │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │ [⭳] Install VHUNAMBI                         [Not now]     [ How? ]│ │ <-- Persistent PWA
│ └────────────────────────────────────────────────────────────────────┘ │     Floating Dock
├────────────────────────────────────────────────────────────────────────┤
│    [Home]        [Explore]        [✨ Create]      [Library]   ─[Market]─│ <-- Active Bottom Tab
└────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Specifications (Marketplace)
1. **Top Header:** Height `56px` (Mobile) / `68px` (Desktop). Back button, brand emblem, centered search input pill (`"Search beats or producers..."`), credit balance chip (`⚡ 10 songs left`), and notification bell.
2. **Page Header:** Shopping bag icon (`Icons.shopping_bag_outlined`, `#F97316`), title `"Beats Marketplace"` (`AppTypography.titleLarge`), subtitle, and ghost filter trigger button (`🎛 Filters`).
3. **Seller Monetization Callout Banner:**
   - Background: `AppColors.surfaceElevated` (`#141418`).
   - Border: `1px solid rgba(249, 115, 22, 0.35)` with subtle amber ambient glow (`BoxShadow(color: Color(0x1AF97316), blurRadius: 16)`).
   - Emblem: Circular container with gold coin glyph (`Icons.monetization_on_outlined`, `#F59E0B`).
   - Copy: `"Sell your beats"`, subtext.
   - Action: Solid orange pill `"Go to Library"` switching to the Library tab.
4. **Beat Card Grid (`BeatCard`):**
   - 2 columns on Mobile (< 768px), 4 columns on Desktop (> 1024px).
   - 1:1 Aspect ratio artwork cover styled with `AppGradients.forGenre(beat.genre)`.
   - Badges: BPM badge (`112 BPM`, top-left) and Musical Key badge (`F# Minor`, top-right) in semi-transparent dark squircle containers.
   - Play audition button: Circular orange button (`36x36px`, `AppColors.brandPrimary`) triggering preview audio through `playerStateProvider`.
   - Title, verified producer tag (`@producer_handle`), genre/tags row.
   - Footer: Price in credits (`⚡ 5 Credits`, `#F97316`, bold) and `"License Beat"` button.
5. **Licensing Modal (`BeatLicenseModal`):**
   - Bottom sheet displaying beat artwork, title, producer, price, non-exclusive commercial terms (stems included, unlimited streaming rights), and confirm button deducting credits and adding track to user's Library vault.
6. **Marketplace Filter Sheet/Dialog:**
   - Real-time filters: Genre selector chips, BPM range slider (70 - 160 BPM), max price slider (1 - 20 credits), and `"Clear all"` action.
7. **Universal Empty State:**
   - 48×48px squircle container (`surfaceElevated`, border `borderSubtle`, corner radius 14px) with shopping bag icon, `"No beats found"`, and subtext.
8. **PWA Install Dock:**
   - Persistent floating card above navigation dock (`#16161C` modal surface, 14px radius) with download icon, `"Install VHUNAMBI"`, `"Not now"`, and solid orange `"How?"` trigger.

---

## 3. Marketing Landing Funnel Scaffolding (`/`)

### 3.1 Visual Hierarchy & Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                        [ ⚡ New: African AI Music ]                    │
│                                                                        │
│                      Create African Music                              │
│                      with a Single Prompt                              │
│                                                                        │
│        Type an idea, pick a genre, and create high-quality songs       │
│        with authentic African rhythms and indigenous languages.        │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────┬─────────┐ │
│  │ A powerful amapiano anthem about rising from hardship...│Generate │ │ <-- Prompt Box
│  └─────────────────────────────────────────────────────────┴─────────┘ │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │                    [ CINEMATIC HERO ARTWORK ]                    │  │
│  │                                                                  │  │
│  │  (▶) Limpopo Sunset • Amapiano • Tshivenḓa   ılılıllı|ı|ı|lılıl   │  │ <-- Sample Player
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  [ 210+ Songs Created ]    [ 27+ Active Musicians ]    [ 1,008 Likes ] │ <-- Metrics Banner
│                                                                        │
│  How It Works:                                                         │
│  ┌──────────────┐       ┌──────────────┐       ┌──────────────┐        │
│  │ 01 ✍️        │  ──>  │ 02 ⚡        │  ──>  │ 03 🚀        │        │
│  │ Describe song│       │ AI generates │       │ Share world  │        │
│  └──────────────┘       └──────────────┘       └──────────────┘        │
│                                                                        │
│  Every Sound on Earth:                                                 │
│  [ All ] [ South Africa ] [ West Africa ] [ East Africa ] [ Central ]  │
│  [ Amapiano ] [ Kwaito ] [ Gqom ] [ Maskandi ] [ Afro House ] ...      │
│                                                                        │
│  6 Core Value Pillars:                                                 │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐              │
│  │ 1. AI-Powered  │ │ 2. Multilingual│ │ 3. African 1st │              │
│  ├────────────────┤ ├────────────────┤ ├────────────────┤              │
│  │ 4. Collaborate │ │ 5. Ownership   │ │ 6. WhatsApp    │              │
│  └────────────────┘ └────────────────┘ └────────────────┘              │
│                                                                        │
│  Cultural Translation Spotlight:                                       │
│  ┌───────────────────────────────┐  ┌────────────────────────────────┐ │
│  │ ❌ Generic AI Translation     │  │ ✅ Vhunambi Indigenous         │ │
│  └───────────────────────────────┘  └────────────────────────────────┘ │
│                                                                        │
│  Creator Testimonials:                                                 │
│  ┌───────────────────────┐  ┌───────────────────────┐                  │
│  │ ⭐⭐⭐⭐⭐ Thohoyandou│  │ ⭐⭐⭐⭐⭐ Johannesburg │                  │
│  └───────────────────────┘  └───────────────────────┘                  │
│                                                                        │
│  Pricing: [ Monthly ] ─[ Yearly (-20%) ]─                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │ Free ($0)   │ │Creator ($9) │ │ Pro ($29) ★ │ │Studio ($119)│       │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                                        │
│  Global Footer:                                                        │
│  (🎵) VHUNAMBI • Tshivenḓa Mission • Product Links • Legal Links       │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Component Specifications (Landing Funnel)
1. **Hero Header:**
   - Pill badge: `[ ⚡ New: African AI Music ]` (`rgba(249,115,22,0.15)`, border `1px solid #F97316`, text `#F97316`).
   - Title: `"Create African Music with a Single Prompt"`. `"African Music"` has gradient fill (`#F97316` to `#F59E0B`).
   - Subtitle: `"Type an idea, pick a genre, and create high-quality songs with authentic African rhythms and indigenous languages."`.
   - Quick-Prompt Bar: Pill TextField (`height: 52px`, `#141418`) with integrated solid orange `"Generate"` CTA button switching to Studio with prompt pre-filled.
   - Hero Audio Showcase: Cinematic card with sample track `"Limpopo Sunset"`, circular amber play trigger, genre/language labels, and reactive amplitude visualizer bars.
2. **Social Proof Counters:**
   - 3-column metric banner: `210+` Songs Created, `27+` Active Musicians & Producers, `1,008` Total Community Likes.
3. **How It Works (3-Step Guided Workflow):**
   - Step 1: `01 ✍️ Describe your song` (theme, mood, lyrics).
   - Step 2: `02 ⚡ AI generates it` (authentic rhythms & lyrics in < 60s).
   - Step 3: `03 🚀 Share with the world` (download MP3s, stems, share to WhatsApp).
   - Section CTA: `✨ Try it now — It's free` routing to Studio.
4. **African Musical Heritage Showcase ("Every Sound on Earth"):**
   - Regional tab selector: `All`, `South Africa`, `West Africa`, `East Africa`, `Central Africa`.
   - 20+ genre chips with interactive audition playback.
5. **Core Value Pillars (6 Feature Cards):**
   - 3x2 responsive grid of feature cards (`#141418` surface, `16px` radius).
6. **Cultural Translation Spotlight:**
   - Side-by-side comparison cards: Generic AI Translation (red border) vs Vhunambi Indigenous Synthesis (emerald border).
7. **Creator Testimonials:**
   - 4 verified creator review cards with star ratings (`⭐⭐⭐⭐⭐`), author avatar, handle, and geographic location (Thohoyandou, Johannesburg, Nairobi, Lagos).
8. **Pricing & Credit Matrix ("Start Free, Scale Up"):**
   - Billing cycle toggle: `Monthly` vs `Yearly (Save 20%)`.
   - 4 subscription cards: `Free` ($0/mo), `Creator` ($9/mo), `Pro` ($29/mo, popular badge), `Studio` ($119/mo).
9. **Global Footer:**
   - Brand emblem, wordmark, Tshivenḓa mission statement (*"vhunambi translates to the talent or ability to sing"*), product navigation links, and legal/licensing links.
