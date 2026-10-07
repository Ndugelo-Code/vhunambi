# Master Handoff Prompt: Phase 6 — Beats Marketplace & Marketing Funnel (`/market` & `/`)

> **To be executed by:** Cline (DeepSeek V4 Flash / 1M Context Window) OR Antigravity IDE  
> **Working Directory:** `apps/vhunambi_client/`  
> **Source Blueprint:** `docs/foundation_blueprints/05_MARKETPLACE_AND_LANDING_SPEC.md`  
> **Phase 4-Doc Suite:** `docs/phases/phase_06_marketplace/` (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`)  
> **Architecture Standard:** `docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`

---

## Pre-Flight Status & Guardrails

1. **Baseline Status:** `dart analyze .` reports **0 issues**. `flutter test` reports **78 of 78 tests passing cleanly (100%)**.
2. **Brand Identity:** Name is strictly **`vhunambi`** (with an **i**, from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
3. **Design Tokens:** Strictly utilize `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` from `package:vhunambi_client/core/theme/`. **NEVER hardcode raw hex values or ad-hoc border radii.**
4. **Collision Safety:** Do NOT import `RepeatMode` from Flutter; our audio repeat enum is `AudioRepeatMode`.
5. **Responsive Utilities:** Use `ResponsiveUtils.isDesktop(context)` (> 1024px) vs `ResponsiveUtils.isMobile(context)` (< 768px).
6. **Layer Hygiene:** Presentation widgets depend on Riverpod providers; providers manipulate immutable domain state models; UI never mutates state directly.
7. **Audio Player Integration:** When auditioning beat previews, use `ref.read(playerStateProvider.notifier).playTrack(track)` so audio plays continuously in the persistent dock.

---

## Phase 6 Implementation Goal

Build out the two remaining primary destinations of Vhunambi's 5-tab root shell:
1. **The Beats Marketplace (`MarketplaceView`)** under `lib/features/marketplace/`, wired into Tab Index 4 of `RootShell`.
2. **The Marketing Landing Funnel (`HomeLandingView`)** under `lib/features/landing/`, wired into Tab Index 0 of `RootShell`.

---

## Step-by-Step Task Sequence

### 1. Domain Models
- **Marketplace Models** (`lib/features/marketplace/domain/models/marketplace_models.dart`):
  - `BeatListingEntity`: `id`, `title`, `producerId`, `producerName`, `producerHandle`, `producerAvatarUrl`, `genre`, `bpm`, `musicalKey`, `priceInCredits`, `previewAudioUrl`, `stemZipUrl`, `licenseType`, `totalSales`, `createdAt`.
    - Getters: `bpmLabel => '$bpm BPM'`, `priceLabel => '⚡ $priceInCredits Credits'`.
  - `MarketplaceFilterState`: `searchQuery`, `genre`, `minBpm`, `maxBpm`, `maxPriceCredits`, `copyWith`.
- **Landing Models** (`lib/features/landing/domain/models/landing_models.dart`):
  - `BillingCycle` enum (`monthly`, `yearly`).
  - `PricingTier`: `id`, `name`, `monthlyPrice`, `yearlyPrice`, `songAllowance`, `audioQuality`, `licenseScope`, `features` (list of strings), `isPopular` (bool), `ctaLabel`.
    - Method: `int priceFor(BillingCycle cycle) => cycle == BillingCycle.yearly ? yearlyPrice : monthlyPrice;`.
  - `CreatorTestimonial`: `id`, `authorName`, `handle`, `location`, `quote`, `rating` (int, default 5), `avatarUrl`.
  - `ValuePillar`: `title`, `description`, `iconData`.

### 2. Riverpod State Providers
- **Marketplace Providers** (`lib/features/marketplace/presentation/providers/marketplace_providers.dart`):
  - `marketplaceFilterProvider` (`StateProvider<MarketplaceFilterState>`).
  - `MarketplaceBeatsNotifier` & `marketplaceBeatsProvider`:
    - Seed 6 high-quality African instrumental beat listings:
      1. `"Township Heat"`, Amapiano, 112 BPM, F# Minor, 5 Credits, `@sipho_beats` (`Sipho`).
      2. `"Durban Midnight Bass"`, Gqom, 128 BPM, A Minor, 5 Credits, `@djvibe` (`DJ Vibe`).
      3. `"Zulu Acoustic Flow"`, Maskandi, 115 BPM, C Major, 5 Credits, `@ndugelo` (`Ndugelo`).
      4. `"Soweto Sunset Groove"`, Afro House, 120 BPM, G Minor, 5 Credits, `@lerato_prod` (`Lerato`).
      5. `"Limpopo Log Drum Rush"`, Amapiano, 114 BPM, E Minor, 5 Credits, `@fifi_music` (`Fifi`).
      6. `"Lagos Afrobeat Horns"`, Afrobeats, 105 BPM, D Minor, 5 Credits, `@ade_sound` (`Ade`).
  - `filteredBeatsProvider`: Computed selector applying search, genre, BPM, and price filters.
  - `auditionBeat(WidgetRef ref, BeatListingEntity beat)`: Player bridge function.
- **Landing Providers** (`lib/features/landing/presentation/providers/landing_providers.dart`):
  - `pricingBillingCycleProvider` (`StateProvider<BillingCycle>`) defaulting to `monthly`.
  - `pricingTiersProvider`: 4 tiers (`Free` $0, `Creator` $9/$7, `Pro` $29/$23 [popular], `Studio` $119/$95).
  - `creatorTestimonialsProvider`: 4 testimonials (Thohoyandou, Johannesburg, Nairobi, Lagos).

### 3. Marketplace UI Components (`lib/features/marketplace/presentation/widgets/`)
- **`marketplace_top_bar.dart`**: Responsive header with back button, brand emblem, centered search input pill (`"Search beats or producers..."`), credit balance chip (`⚡ 10 songs left`), and notification bell.
- **`seller_callout_banner.dart`**: Elevated container (`AppColors.surfaceElevated`) with amber ambient glow (`BoxShadow(color: Color(0x1AF97316), blurRadius: 16)`), gold coin icon (`Icons.monetization_on_outlined`), headline `"Sell your beats"`, explanatory subtext, and solid orange pill CTA `"Go to Library"`.
- **`beat_card.dart`**: 1:1 artwork cover container with `AppGradients.forGenre(beat.genre)`, BPM badge (`112 BPM`), Musical Key badge (`F# Minor`), circular orange audition play button (`36x36px`), title, verified producer tag, credit price (`⚡ 5 Credits`), and `"License Beat"` button.
- **`beat_license_modal.dart`**: Bottom modal sheet showing beat details, commercial terms, and credit deduction confirmation.
- **`marketplace_filter_modal.dart`**: Filter sheet with genre chips, BPM slider (70-160 BPM), and credit price slider.
- **`marketplace_empty_state.dart`**: 48×48px squircle container, `"No beats found"`, and listing guidance.
- **`pwa_install_dock.dart`**: Persistent floating install dock with `"Install VHUNAMBI"`, `"Not now"`, and `"How?"` action buttons.

### 4. Marketplace Screen Assembly (`lib/features/marketplace/presentation/views/marketplace_view.dart`)
- Composes top bar, header title with shopping bag icon (`Icons.shopping_bag_outlined`, `#F97316`), seller monetization banner, beat cards grid (2-col mobile vs 4-col desktop), empty state, and floating PWA install dock.
- Wires `onNavigateToLibrary` to switch root shell to Library tab (index 3).

### 5. Landing Funnel UI Components (`lib/features/landing/presentation/widgets/`)
- **`landing_hero_section.dart`**: `[ ⚡ New: African AI Music ]` top badge, H1 `"Create African Music with a Single Prompt"` with orange-to-amber text gradient, subtitle, quick-prompt input bar with `"Generate"` button, and cinematic sample audio card (`"Limpopo Sunset"` • Amapiano • Tshivenḓa, interactive waveform).
- **`social_proof_counters.dart`**: 3-column metric banner: `210+` Songs Created, `27+` Active Musicians, `1,008` Total Likes.
- **`how_it_works_section.dart`**: 3-step cards: `01 ✍️ Describe your song`, `02 ⚡ AI generates it`, `03 🚀 Share with the world` + solid orange CTA `✨ Try it now — It's free`.
- **`heritage_genre_showcase.dart`**: 20+ African genres with regional tabs (`All`, `South Africa`, `West Africa`, `East Africa`, `Central Africa`).
- **`value_pillars_grid.dart`**: 3x2 grid of 6 core feature cards.
- **`cultural_translation_spotlight.dart`**: Side-by-side comparison cards (Generic AI vs Vhunambi Indigenous Synthesis).
- **`testimonials_wall.dart`**: 4 creator review cards with star ratings (`⭐⭐⭐⭐⭐`), author avatar, handle, and location.
- **`pricing_matrix_section.dart`**: Billing cycle toggle (`Monthly` / `Yearly - Save 20%`), 4 pricing cards with feature checks.
- **`landing_footer.dart`**: Brand emblem, Tshivenḓa mission statement, product links, and legal/licensing links.

### 6. Home Landing Screen Assembly (`lib/features/landing/presentation/views/home_landing_view.dart`)
- Scrollable landing page composing all landing sections above.
- Wires `onGetStarted` to switch root shell to Studio tab (index 2).

### 7. RootShell Integration (`lib/main.dart`)
- Replace Tab Index 0 with `HomeLandingView(onGetStarted: _openStudio)`.
- Replace Tab Index 4 with `MarketplaceView(onNavigateToLibrary: _openLibrary)`.
- Add `void _openLibrary() => setState(() => _currentIndex = 3);`.

### 8. Automated Tests
- Unit tests:
  - `test/features/marketplace/marketplace_notifier_test.dart` (filtering, search, credit pricing, sorting).
  - `test/features/landing/landing_providers_test.dart` (pricing calculations, billing cycle toggle, testimonials).
- Widget tests:
  - `test/features/marketplace/marketplace_view_test.dart` (top bar, beat cards grid, license modal, filter modal, PWA dock).
  - `test/features/landing/home_landing_view_test.dart` (hero section, prompt navigation, pricing cards, footer).

---

## Verification Criteria
- `dart analyze .` must report `No issues found!`.
- `flutter test` must pass all test cases without regression (all 78 baseline tests + new marketplace/landing tests).

---

## Execution Record — 2026-09-23 ✅

**Status:** Phase 6 complete and verified. `dart analyze .` → `No issues found!` (0 issues). `flutter test` → `114 of 114 tests passed!` (78 Phase 5 baseline + 36 new marketplace/landing tests).

### Delivered Under `apps/vhunambi_client/`
* `lib/features/marketplace/domain/models/marketplace_models.dart` — `BeatListingEntity` (`bpmLabel`, `priceLabel`, `previewDuration`, `copyWith`/`==`), `MarketplaceFilterState` (`hasActiveFilters`, `cleared()`, clear flags on `copyWith`), the 12-genre catalog and the 180s preview contract.
* `lib/features/marketplace/presentation/providers/marketplace_providers.dart` — `marketplaceFilterProvider`, marketplace credit balance, `MarketplaceBeatsNotifier` (6 seeded listings + `registerSale`/`addListing`), pure `filterBeats()`, `filteredBeatsProvider`, `auditionBeat()`, `licenseBeat()` (`BeatLicenseOutcome`), `clearMarketplaceFilters()`.
* `lib/features/marketplace/presentation/widgets/` — `marketplace_top_bar.dart` (68/56px, search + credit chip + bell), `seller_callout_banner.dart` (amber glow), `beat_card.dart` (BPM/key badges, audition trigger, price + licensing CTA), `beat_license_modal.dart`, `marketplace_filter_modal.dart` (genre chips, 70–160 BPM range slider, 1–20 credit slider, Clear all), `marketplace_empty_state.dart`, `pwa_install_dock.dart`.
* `lib/features/marketplace/presentation/views/marketplace_view.dart` — header with bag icon + `Filters`, seller banner, 2/3/4-column listing grid, empty state, floating PWA dock.
* `lib/features/landing/domain/models/landing_models.dart` — `BillingCycle`, `PricingTier` (`priceFor`), `CreatorTestimonial` (`initials`), `ValuePillar`, `LandingMetric`, `LandingGenre` + the 27-genre / 5-region catalogue.
* `lib/features/landing/presentation/providers/landing_providers.dart` — billing cycle, 4 pricing tiers, 4 testimonials, 6 pillars, 3 metrics, regional genre filtering, hero prompt + showcase track, `submitLandingPrompt()`, `auditionLandingShowcase()`, `auditionGenrePreview()`.
* `lib/features/landing/presentation/widgets/` — the nine funnel sections (hero with gradient headline + prompt bar + showcase, social proof, 3-step workflow, heritage showcase, value pillars, translation spotlight, testimonials wall, pricing matrix, footer).
* `lib/features/landing/presentation/views/home_landing_view.dart` — 9-section funnel composition.
* `lib/core/theme/app_colors.dart` — additive `AppColors.coinGold` (`#F59E0B`).
* `lib/main.dart` — `RootShell` tab 0 `HomeLandingView(onGetStarted: _openStudio)` and tab 4 `MarketplaceView(onNavigateToLibrary: _openLibrary)`.
* Tests: `test/features/marketplace/marketplace_notifier_test.dart` (13), `test/features/landing/landing_providers_test.dart` (9), `test/features/marketplace/marketplace_view_test.dart` (7), `test/features/landing/home_landing_view_test.dart` (7).

### Spec Deviations / Additions (documented for the auditor)
1. **Licensing transaction:** REQ-MKT-04's "deduct credits + save into the Library vault" is implemented as `licenseBeat(ref, beat)` → decrements `marketplaceCreditsProvider`, calls the existing Phase 4 `libraryTracksProvider.notifier.addTrack(...)` with a `marketplace_<beatId>` record (`isInstrumental: true`, commercial licence, 180s preview length) and registers the sale. Insufficient balances surface an inline shortfall message instead of silently failing.
2. **Master credit balance:** the marketplace header's `⚡ 10 songs left` chip is now driven by `marketplaceCreditsProvider` (the studio/library/explore chips remain static strings until a shared credits feature lands).
3. **Beat preview duration:** `BeatListingEntity` carries no duration field, so auditions use the 180s preview contract from design.md §2.1 (`beatPreviewDurationSeconds`).
4. **Tablet marketplace grid:** the spec fixes 2 columns (mobile) and 4 (desktop); tablet widths additively use 3 columns.
5. **Landing waveform:** the hero showcase uses a static amplitude visualizer with tap-to-seek (`seekByRatio`) instead of the Phase 2 `WaveformBars`, whose always-repeating animation prevents `pumpAndSettle` from settling; the interaction contract is preserved without the battery/animation cost.
6. **Genre chip auditioning:** chips audition the first marketplace listing in that genre (real preview URLs). Genres without a listing announce that no preview exists yet.
7. **Landing sections beyond the blueprint detail:** the 27-genre heritage catalogue (grouped across the five regional tabs) and the pricing feature bullets follow design.md §2.2; the review-driven `For You`/social features remain deferred to Phase 7.
8. **Pricing CTAs / footer links:** presentational until the billing and settings phases land (documented in the bible notes).
