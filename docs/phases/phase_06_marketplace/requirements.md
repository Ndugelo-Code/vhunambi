# Phase 6 Requirements: Beats Marketplace & Marketing Funnel (`/market` & `/`)

> **Specification Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `MAY`)  
> **Traceability Root:** `REQ-MKT`

---

## 1. Beats Marketplace Requirements (`/market`)

- **REQ-MKT-01 (Marketplace Header & Scaffolding):**
  - The Marketplace view **MUST** render a top navigation header adhering to the responsive specification:
    - Back chevron, brand emblem, centered search input pill (`"Search beats or producers..."`), credit balance chip (`⚡ 10 songs left`), and notification bell.
  - The page header **MUST** render a shopping bag icon (`Icons.shopping_bag_outlined`, `#F97316`), title `"Beats Marketplace"`, descriptive subtitle, and ghost filter trigger button (`🎛 Filters`).

- **REQ-MKT-02 (Seller Monetization Callout Banner):**
  - The view **MUST** render an elevated monetization banner in `AppColors.surfaceElevated` with a 1px border colored `rgba(249, 115, 22, 0.35)` and subtle amber ambient glow (`BoxShadow(color: Color(0x1AF97316), blurRadius: 16)`).
  - The banner **MUST** display a gold coin emblem (`Icons.monetization_on_outlined`), headline `"Sell your beats"`, explanatory subtext, and a solid orange CTA `"Go to Library"` that navigates to the Library tab.

- **REQ-MKT-03 (Responsive Beat Listing Cards):**
  - Beat listings **MUST** render as:
    - Exactly 2 columns on Mobile (< 768px).
    - Exactly 4 columns on Desktop (> 1024px).
  - Each `BeatCard` **MUST** display:
    - 1:1 Aspect ratio artwork cover styled with `AppGradients.forGenre(beat.genre)`.
    - BPM badge (`112 BPM`, top-left) and Musical Key badge (`F# Minor`, top-right).
    - Circular orange play audition button (`36x36px`) triggering preview audio through `playerStateProvider`.
    - Beat title, verified producer tag (`@producer`), genre/tags.
    - Footer row with credit price (`⚡ 5 Credits`, `#F97316`, bold) and `"License Beat"` button.

- **REQ-MKT-04 (Commercial Beat Licensing Flow & Modal):**
  - Tapping `"License Beat"` **MUST** open a modal bottom sheet displaying:
    - Beat artwork, title, producer, price in credits.
    - Commercial licensing terms (non-exclusive commercial sync, lossless stems, unlimited streaming).
    - Confirmation action button that deducts credits and saves the beat into the user's Library vault with commercial license record.

- **REQ-MKT-05 (Marketplace Filter Engine & Universal Empty State):**
  - Tapping `🎛 Filters` **MUST** present a filter sheet/dialog allowing users to filter by:
    - Genre (all 12 African genres).
    - BPM range (70 to 160 BPM).
    - Maximum credit price.
  - When no listings match active filters, the UI **MUST** display an empty state (`48x48px` squircle container, `Icons.shopping_bag_outlined`, `"No beats found"`, and subtext).

- **REQ-MKT-06 (Persistent PWA Floating Installation Dock):**
  - The marketplace view **MUST** render a floating card above the navigation dock prompting `"Install VHUNAMBI"`.
  - It **MUST** include download icon, helper copy, text button `"Not now"`, and solid orange pill button `"How?"`.

---

## 2. Marketing Landing Funnel Requirements (`/`)

- **REQ-MKT-07 (Hero Section, Quick-Prompt Bar & Showcase Player):**
  - The landing page **MUST** render:
    - Centered top pill badge `[ ⚡ New: African AI Music ]`.
    - H1 headline `"Create African Music with a Single Prompt"`, with `"African Music"` styled using an orange-to-amber text gradient (`#F97316` to `#F59E0B`).
    - Subtitle describing multi-genre, indigenous language creation.
    - Quick-prompt TextField (`height: 52px`, `#141418`) with integrated `"Generate"` button routing to Studio with the entered prompt pre-filled.
    - Hero audio showcase card (`"Limpopo Sunset"` • Amapiano • Tshivenḓa) with circular amber play button, interactive waveform scrubber, and audition playback.

- **REQ-MKT-08 (Social Proof Counters & 3-Step Guided Workflow):**
  - The page **MUST** render a 3-column metric banner: `210+` Songs Created, `27+` Active Musicians & Producers, `1,008` Total Community Likes.
  - The page **MUST** render a 3-step workflow section:
    1. `01 ✍️ Describe your song`
    2. `02 ⚡ AI generates it`
    3. `03 🚀 Share with the world`
  - The section **MUST** include the CTA button `✨ Try it now — It's free` routing to Studio.

- **REQ-MKT-09 (20+ Heritage Genre Showcase & 6 Core Value Pillars):**
  - The page **MUST** render an interactive genre showcase covering 20+ African genres with regional tabs (`All`, `South Africa`, `West Africa`, `East Africa`, `Central Africa`).
  - The page **MUST** render 6 value pillar cards in a 3x2 responsive grid:
    1. AI-Powered Generation
    2. Multilingual Linguistic Engine
    3. African Genres First
    4. Collaborate in Real Time
    5. Download & Full Ownership
    6. Direct WhatsApp & Social Sharing

- **REQ-MKT-10 (Cultural Translation Spotlight & Testimonials Wall):**
  - The page **MUST** render side-by-side comparative cards contrasting Generic AI Translation (red accent) against Vhunambi Indigenous Synthesis (emerald accent).
  - The page **MUST** render 4 verified creator testimonial cards featuring 5-star ratings (`⭐⭐⭐⭐⭐`), author avatar, handle, and geographic location (Thohoyandou, Johannesburg, Nairobi, Lagos).

- **REQ-MKT-11 (Pricing Matrix & Global Footer):**
  - The page **MUST** render a 4-tier pricing matrix: `Free` ($0), `Creator` ($9), `Pro` ($29, highlighted popular tier), `Studio` ($119), with a billing cycle toggle (`Monthly` vs `Yearly - Save 20%`).
  - The page **MUST** render a global footer with brand mark, Tshivenḓa mission statement, product links, and legal/licensing links.

- **REQ-MKT-12 (Riverpod State & Shell Integration):**
  - State management **MUST** expose Riverpod providers for:
    - `marketplaceFilterProvider` (`MarketplaceFilterState`)
    - `marketplaceBeatsProvider` (`MarketplaceBeatsNotifier` with seeded beats)
    - `filteredBeatsProvider` (computed selector reflecting search, genre, BPM, price)
    - `pricingBillingCycleProvider` (`BillingCycle`: `monthly`, `yearly`)
  - `RootShell` in `lib/main.dart` **MUST** mount:
    - Tab index 0: `HomeLandingView`
    - Tab index 4: `MarketplaceView`
