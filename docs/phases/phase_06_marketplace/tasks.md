# Phase 6 Tasks & Verification Plan: Beats Marketplace & Marketing Funnel (`/market` & `/`)

> **Status:** ✅ Executed & Verified — 2026-09-23 (0 analysis issues, 114/114 automated tests passing)
> **Target:** `apps/vhunambi_client`  
> **Parent Spec:** `docs/phases/phase_06_marketplace/`  
> **Source Origin:** [`docs/foundation_blueprints/05_MARKETPLACE_AND_LANDING_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/05_MARKETPLACE_AND_LANDING_SPEC.md)

---

## 1. Pre-Flight Codebase Anchors

- [x] Baseline verification: `dart analyze .` reports `0 issues`.
- [x] Automated tests: All 78 existing tests pass cleanly (`flutter test`).
- [x] Token verification: `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` available in `package:vhunambi_client/core/theme/`.
- [x] Enum safety: Audio repeat enum is `AudioRepeatMode` (never `RepeatMode`).
- [x] Shell integration anchor: `RootShell` in `lib/main.dart` mounts tabs: Index 0 (Home), Index 1 (Explore), Index 2 (Create), Index 3 (Library), Index 4 (Marketplace).

---

## 2. Sequenced Implementation Tasks

- [x] **Task 6.1: Domain Models & Enums**
  - Path: `lib/features/marketplace/domain/models/marketplace_models.dart`:
    - `BeatListingEntity` (id, title, producerId, producerName, producerHandle, genre, bpm, musicalKey, priceInCredits, previewAudioUrl, licenseType, totalSales, createdAt).
    - `MarketplaceFilterState` (searchQuery, genre, minBpm, maxBpm, maxPriceCredits, copyWith).
  - Path: `lib/features/landing/domain/models/landing_models.dart`:
    - `BillingCycle` enum (`monthly`, `yearly`).
    - `PricingTier` entity (id, name, monthlyPrice, yearlyPrice, songAllowance, audioQuality, licenseScope, features, isPopular, ctaLabel).
    - `CreatorTestimonial` entity (id, authorName, handle, location, quote, rating, avatarUrl).
    - `ValuePillar` entity (title, description, iconData).

- [x] **Task 6.2: Riverpod State Providers**
  - Path: `lib/features/marketplace/presentation/providers/marketplace_providers.dart`:
    - `marketplaceFilterProvider` (`StateProvider<MarketplaceFilterState>`).
    - `marketplaceBeatsProvider` (`MarketplaceBeatsNotifier`) with 6 seeded African beats (Amapiano, Gqom, Maskandi, Afro House, Afrobeats).
    - `filteredBeatsProvider` (computed selector reflecting search, genre, BPM, price).
    - `auditionBeat(WidgetRef ref, BeatListingEntity beat)` player bridge function.
  - Path: `lib/features/landing/presentation/providers/landing_providers.dart`:
    - `pricingBillingCycleProvider` (`BillingCycle.monthly`).
    - `pricingTiersProvider` (Free, Creator, Pro, Studio).
    - `creatorTestimonialsProvider` (4 regional testimonials).

- [x] **Task 6.3: Marketplace UI Components**
  - Path: `lib/features/marketplace/presentation/widgets/`:
    - `marketplace_top_bar.dart` (responsive header: back, brand emblem, search pill, credit chip `⚡ 10 songs left`, notification bell).
    - `seller_callout_banner.dart` (elevated container with ambient amber glow `rgba(249, 115, 22, 0.35)`, gold coin icon, `"Sell your beats"`, and `"Go to Library"` CTA).
    - `beat_card.dart` (1:1 artwork cover with genre gradient, BPM & Key badges, audition play trigger, producer tag, price, and `"License Beat"` button).
    - `beat_license_modal.dart` (commercial license confirmation modal with stem delivery details).
    - `marketplace_filter_modal.dart` (genre chips, BPM range slider, credit price slider).
    - `marketplace_empty_state.dart` (48×48px squircle, `"No beats found"`, and listing guidance).
    - `pwa_install_dock.dart` (persistent floating install prompt with `"Not now"` and `"How?"` buttons).

- [x] **Task 6.4: Marketplace Screen Assembly (`MarketplaceView`)**
  - Path: `lib/features/marketplace/presentation/views/marketplace_view.dart`:
    - Assembles top bar, header title with shopping bag icon, seller callout banner, beat cards grid (2-col mobile vs 4-col desktop), empty state, and PWA install dock.
    - Wire `onNavigateToLibrary` callback.

- [x] **Task 6.5: Landing Funnel UI Components**
  - Path: `lib/features/landing/presentation/widgets/`:
    - `landing_hero_section.dart` (new badge, H1 with orange-to-amber text gradient, subtitle, quick-prompt bar with `"Generate"` button, and cinematic sample audio card with interactive waveform).
    - `social_proof_counters.dart` (210+ songs, 27+ musicians, 1,008 likes).
    - `how_it_works_section.dart` (3-step workflow: Describe, Generate, Share + CTA).
    - `heritage_genre_showcase.dart` (20+ African genres with regional tabs).
    - `value_pillars_grid.dart` (6 feature cards: AI, Multilingual, African 1st, Collaborate, Ownership, WhatsApp).
    - `cultural_translation_spotlight.dart` (Generic AI vs Vhunambi Indigenous side-by-side comparison).
    - `testimonials_wall.dart` (4 creator review cards with star ratings).
    - `pricing_matrix_section.dart` (Monthly/Yearly toggle, 4 pricing cards with feature checks).
    - `landing_footer.dart` (Tshivenḓa mission statement, product links, legal/licensing links).

- [x] **Task 6.6: Home Landing Screen Assembly (`HomeLandingView`)**
  - Path: `lib/features/landing/presentation/views/home_landing_view.dart`:
    - Scrollable landing page composing all landing sections.
    - Wire `onGetStarted` callback routing to Studio tab (index 2).

- [x] **Task 6.7: RootShell Integration in `lib/main.dart`**
  - Mount `HomeLandingView(onGetStarted: _openStudio)` at tab index 0.
  - Mount `MarketplaceView(onNavigateToLibrary: _openLibrary)` at tab index 4.

- [x] **Task 6.8: Automated Tests & Verification**
  - Unit tests: `test/features/marketplace/marketplace_notifier_test.dart` (filtering, search, credit pricing, sorting).
  - Unit tests: `test/features/landing/landing_providers_test.dart` (pricing calculations, billing cycle toggle, testimonials).
  - Widget tests: `test/features/marketplace/marketplace_view_test.dart` (top bar, beat cards grid, license modal, filter modal, PWA dock).
  - Widget tests: `test/features/landing/home_landing_view_test.dart` (hero, prompt bar navigation, pricing cards, footer).
  - Run `dart analyze .` (0 issues).
  - Run `flutter test` (100% pass rate).

---

## 3. Verification Commands & Gate Thresholds

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze .
flutter test
```

- Static Analysis Gate: `Analyzing .... No issues found!` (0 issues).
- Test Gate: `All tests passed!` (>= 78 baseline + new marketplace and landing tests).

---

## 4. Execution Results (2026-09-23)

### Gate Output
```powershell
cd apps/vhunambi_client
dart analyze .
# Result: Analyzing .... No issues found! (0 issues)

flutter test
# Result: 114 of 114 tests passed! (100%)
```

### Delivered Files
| Artifact | Path |
| :--- | :--- |
| Marketplace models | `lib/features/marketplace/domain/models/marketplace_models.dart` |
| Marketplace state | `lib/features/marketplace/presentation/providers/marketplace_providers.dart` |
| Marketplace widgets | `marketplace_top_bar.dart`, `seller_callout_banner.dart`, `beat_card.dart`, `beat_license_modal.dart`, `marketplace_filter_modal.dart`, `marketplace_empty_state.dart`, `pwa_install_dock.dart` |
| Marketplace screen | `lib/features/marketplace/presentation/views/marketplace_view.dart` |
| Landing models | `lib/features/landing/domain/models/landing_models.dart` |
| Landing state | `lib/features/landing/presentation/providers/landing_providers.dart` |
| Landing widgets | `landing_hero_section.dart`, `social_proof_counters.dart`, `how_it_works_section.dart`, `heritage_genre_showcase.dart`, `value_pillars_grid.dart`, `cultural_translation_spotlight.dart`, `testimonials_wall.dart`, `pricing_matrix_section.dart`, `landing_footer.dart` |
| Landing screen | `lib/features/landing/presentation/views/home_landing_view.dart` |
| Theme token | `lib/core/theme/app_colors.dart` (`AppColors.coinGold`) |
| Shell wiring | `lib/main.dart` → tab 0 `HomeLandingView`, tab 4 `MarketplaceView` |
| Marketplace unit tests (13) | `test/features/marketplace/marketplace_notifier_test.dart` |
| Landing unit tests (9) | `test/features/landing/landing_providers_test.dart` |
| Marketplace widget tests (7) | `test/features/marketplace/marketplace_view_test.dart` |
| Landing widget tests (7) | `test/features/landing/home_landing_view_test.dart` |

### Deferred to Later Phases
* Real credit purchase / billing settlement, PWA service-worker registration and creator-profile routes (`/track/:id`, `/profile/:id`) land with Phases 7–8.
* Marketing CTAs (pricing buttons, footer links) and the master PWA install flow remain presentational.
