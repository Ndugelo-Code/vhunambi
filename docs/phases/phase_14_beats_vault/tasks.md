# Phase 14 · Tasks — Producer Beats Vault & Beatstore Listing Cockpit

> **Phase:** 14  
> **Codename:** `beats-vault`  
> **Baseline:** `dart analyze .` = 0 issues | `flutter test` = 541/541 passing (100%)  
> **Target:** `dart analyze .` = 0 issues | `flutter test` = ≥ 576 (≥ 35 new tests, 0 regressions)  

---

## Pre-Flight Checks (Run Before Writing Any Code)

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze .          # MUST report: No issues found!
flutter test --no-pub   # MUST report: 541 tests passed (0 failures)
```

Both gates MUST pass before proceeding to Task 1.

---

## Task 1 — Constants (10 min)

**File:** `lib/core/constants/app_constants.dart`

- [ ] Add `beatsBoxKey` constant:
  ```dart
  static const String beatsBoxKey = 'vhunambi_beats';
  ```

**Verification:** `dart analyze .` → 0 issues.

---

## Task 2 — Domain Models (30 min)

**File:** `lib/features/beats/domain/models/producer_beat_entity.dart`

- [ ] Define `BeatStatus` enum (`draft`, `published`, `archived`) with `label`, `toJson()`, `fromJson()`.
- [ ] Define `BeatLicenseTier` enum (`nonExclusiveCommercial`, `exclusiveOwnership`, `syncLicense`, `personalLease`) with `label`, `defaultPriceCredits`, `toJson()`, `fromJson()`.
- [ ] Define `BeatStemPackage` immutable value object:
  - `drumsUrl`, `bassUrl`, `melodyUrl`, `otherUrl`, `isSeparated`.
  - `stemCount`, `hasAllStems`, `copyWith`, JSON serialization, equality.
- [ ] Define `BeatSaleRecord` immutable value object:
  - `saleId`, `buyerId`, `buyerHandle`, `licenseTier`, `creditsEarned`, `timestamp`.
  - JSON serialization, equality.
- [ ] Define `ProducerBeatEntity` aggregate:
  - Fields per REQ-BEAT-01.
  - Computed: `isPublished`, `totalSales`, `totalEarningsCredits`, `bpmLabel`, `priceLabel`, `statusLabel`, `keyLabel`.
  - `copyWith`, `toJson`, `fromJson`, `operator ==`, `hashCode`.

**Verification:** Unit tests in Task 12 verify model construction, serialization, and equality.

---

## Task 3 — Repository Interface (15 min)

**File:** `lib/features/beats/domain/repositories/i_beat_repository.dart`

- [ ] Define `IBeatRepository` abstract interface with all 9 methods per REQ-BEAT-07:
  - `getAllBeats()`, `getBeatById()`, `saveBeat()`, `deleteBeat()`, `publishBeat()`, `unpublishBeat()`, `recordSale()`, `incrementAuditions()`, `clearAll()`.

**Verification:** `dart analyze .` → 0 issues.

---

## Task 4 — `InMemoryBeatRepository` (20 min)

**File:** `lib/features/beats/data/repositories/in_memory_beat_repository.dart`

- [ ] Implement `IBeatRepository` storing entities in an internal list.
- [ ] Pre-seed 3 realistic African beats:
  - `beat_soshanguve` (Amapiano, 112 BPM, F# Minor, Published)
  - `beat_durban` (Gqom, 128 BPM, C Major, Published)
  - `beat_sophiatown` (Kwaito, 106 BPM, A Minor, Draft)
- [ ] Guarantee newest-first sorting (`createdAt` descending).
- [ ] Implement `publishBeat` (status $\rightarrow$ `published`), `unpublishBeat` (status $\rightarrow$ `draft`), `recordSale`, and `incrementAuditions`.

**Verification:** Unit tests verify repository CRUD operations.

---

## Task 5 — `BeatRepository` (Hive-Backed) (25 min)

**File:** `lib/features/beats/data/repositories/beat_repository.dart`

- [ ] Implement `IBeatRepository` using `Hive.box(AppConstants.beatsBoxKey)`.
- [ ] Include safe initialization check: `Hive.isBoxOpen(AppConstants.beatsBoxKey)`.
- [ ] If Hive is closed/uninitialized, silently fall back to an internal memory map for 100% headless `flutter_test` safety.
- [ ] Persist entities as JSON string maps.

**Verification:** Unit tests verify persistence round-trip and headless fallback.

---

## Task 6 — Providers & Filter Engine (30 min)

**File:** `lib/features/beats/presentation/providers/beats_provider.dart`

- [ ] Define `BeatsSortOrder` enum.
- [ ] Define `BeatsVaultFilterState` and `BeatsVaultStats` immutable classes.
- [ ] Define `beatRepositoryProvider` defaulting to `BeatRepository()`.
- [ ] Define `BeatsNotifier` (`StateNotifier<List<ProducerBeatEntity>>`):
  - `loadBeats()`, `createBeat()`, `updateBeat()`, `deleteBeat()`, `publishToMarket()`, `unpublishFromMarket()`, `recordSale()`, `recordAudition()`, `convertTrackToBeat()`.
  - When publishing/unpublishing, automatically call `marketplaceBeatsProvider.notifier.addListing(...)` or sync state.
- [ ] Define `beatsVaultFilterProvider` (`StateProvider<BeatsVaultFilterState>`).
- [ ] Define `filteredBeatsVaultProvider` (`Provider<List<ProducerBeatEntity>>`).
- [ ] Define `beatsVaultStatsProvider` (`Provider<BeatsVaultStats>`).

**Verification:** Unit tests verify provider emissions, filtering, sorting, and stats calculation.

---

## Task 7 — UI Presentation Widgets (35 min)

**Files in `lib/features/beats/presentation/widgets/`:**

- [ ] `beat_status_badge.dart`: Renders green Published, amber Draft, or grey Archived pill badge.
- [ ] `beat_stats_banner.dart`: Renders 4 producer metric cards (Total Beats, Listed, Sales, Credits Earned).
- [ ] `beat_card.dart`: Grid card with regional genre gradient, BPM & Key badges, status badge, title, price, sales count, audition play button, and overflow menu.
- [ ] `beat_list_tile.dart`: `Material`-wrapped row with genre squircle, play button, metadata, price chip, status switch, and menu.

**Verification:** `dart analyze .` → 0 issues.

---

## Task 8 — Modals & Dialogs (30 min)

**Files in `lib/features/beats/presentation/widgets/`:**

- [ ] `beat_form_dialog.dart`: Dialog for creating/editing a beat with title, genre dropdown, BPM slider & tap-tempo, key picker, tags input, price dropdown, and tier selector.
- [ ] `publish_beat_modal.dart`: Sheet explaining 180s preview length, 100% credit royalty, and confirm publish button.
- [ ] `stem_export_modal.dart`: Sheet displaying 4-stem availability, individual audition/download, and export ZIP manifest action.

**Verification:** `dart analyze .` → 0 issues.

---

## Task 9 — `BeatsVaultView` Screen (35 min)

**File:** `lib/features/beats/presentation/views/beats_vault_view.dart`

- [ ] Assemble top `BeatStatsBanner`.
- [ ] Search input with real-time query filtering.
- [ ] Status filter chips (`All`, `Published`, `Draft`).
- [ ] View mode toggle (`Grid` / `List`).
- [ ] `+ New Beat` primary action button opening `BeatFormDialog`.
- [ ] Empty state rendering `LibraryEmptyState(category: LibraryCategory.beats)`.
- [ ] Responsive grid (2/3/4 cols) and dense list rendering.
- [ ] Card/tile tap routes to `BeatDetailCockpitView`.

**Verification:** Widget tests verify rendering, filtering, empty state, and modal triggers.

---

## Task 10 — `BeatDetailCockpitView` Screen (35 min)

**File:** `lib/features/beats/presentation/views/beat_detail_cockpit_view.dart`

- [ ] AppBar with back chevron, beat title, and overflow menu.
- [ ] Hero section with 160×160 artwork, title, producer handle, tags, and `[▶ Audition Preview]` CTA.
- [ ] Marketplace status card with one-tap `[Publish to Marketplace]` / `[Switch to Draft]` toggle button.
- [ ] Stems package card with 4 stem chips and `[⭳ Export Stems Bundle]` CTA.
- [ ] Sales & royalty transaction ledger showing recent buyer licenses and credits earned.

**Verification:** Widget tests verify cockpit inspection, publishing toggle, and stem modal trigger.

---

## Task 11 — Cross-Subsystem Integration (20 min)

**Files:**
- `lib/features/library/presentation/views/library_view.dart`
- `lib/features/marketplace/presentation/providers/marketplace_providers.dart`

- [ ] In `library_view.dart`, mount `BeatsVaultView(onCreateRequested: onCreateRequested)` when `category == LibraryCategory.beats`.
- [ ] Ensure `[Go to Library]` from `SellerCalloutBanner` in `/market` navigates directly into the active beats tab.

**Verification:** `dart analyze .` → 0 issues.

---

## Task 12 — Automated Test Suites (45 min)

**Files in `test/features/beats/`:**

- [ ] `domain/models/producer_beat_entity_test.dart` (≥ 12 tests)
  - `BeatStatus`, `BeatLicenseTier`, `BeatStemPackage`, `BeatSaleRecord` serialization and defaults.
  - `ProducerBeatEntity` computed properties, `copyWith`, and JSON round-trip.
- [ ] `data/repositories/beat_repository_test.dart` (≥ 10 tests)
  - `InMemoryBeatRepository` seeding, CRUD, publish/unpublish, sale recording.
  - `BeatRepository` Hive persistence and headless memory fallback.
- [ ] `presentation/providers/beats_provider_test.dart` (≥ 8 tests)
  - StateNotifier actions, filtering, sorting, and stats calculation.
- [ ] `presentation/views/beats_vault_view_test.dart` (≥ 5 tests)
  - Vault rendering, status filtering, empty state, and create dialog launch.
- [ ] `presentation/views/beat_detail_cockpit_view_test.dart` (≥ 5 tests)
  - Cockpit layout, audition trigger, publish toggle, and stems modal open.

**Verification:** `flutter test test/features/beats/` → all passing.

---

## Task 13 — Verification Gate & Walkthrough (15 min)

- [ ] Run static analysis: `dart analyze .` → MUST report **0 issues**.
- [ ] Run full test suite: `flutter test --no-pub` → MUST report **≥ 576 tests passed (0 failures)**.
- [ ] Create `docs/phases/phase_14_beats_vault/walkthrough.md` documenting task ledger, test inventory, and decisions.
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md` to reflect Phase 14 completion.
