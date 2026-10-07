# Phase 14 · Requirements — Producer Beats Vault & Beatstore Listing Cockpit

> **Phase:** 14  
> **Codename:** `beats-vault`  
> **Standard:** RFC 2119 (MUST, SHALL, SHOULD, MAY) + EARS (Ubiquitous, Event-driven, State-driven, Optional)  
> **Parent Blueprint:** `docs/phases/phase_14_beats_vault/blueprint.md`  

---

## 1. Domain Model Requirements

### REQ-BEAT-01 — Producer Beat Entity
The system **MUST** define an immutable `ProducerBeatEntity` class in `lib/features/beats/domain/models/producer_beat_entity.dart` with the following fields:
- `id: String` — Unique identifier prefixed `beat_`.
- `trackId: String?` — Optional identifier linking to an originating `LibraryTrack.id`.
- `title: String` — Beat display title (trimmed, non-empty).
- `producerId: String` — Producer identifier (default: `'current_user'`).
- `producerName: String` — Producer display name.
- `producerHandle: String` — Producer social handle (e.g. `'@producer'`).
- `genre: String` — Musical genre (e.g. `'Amapiano'`, `'Kwaito'`, `'Gqom'`, `'Afro House'`).
- `bpm: int` — Tempo in beats per minute (range: 40–260, standard default 112).
- `musicalKey: String` — Root key and mode (e.g. `'F# Minor'`, `'C Major'`).
- `tags: List<String>` — Descriptive production tags (e.g. `['Log Drum', 'Private School']`).
- `priceInCredits: int` — Purchase price in platform credits (default: 10, range: 1–100).
- `licenseTier: BeatLicenseTier` — Licensing tier (default: `BeatLicenseTier.nonExclusiveCommercial`).
- `status: BeatStatus` — Publishing status (default: `BeatStatus.draft`).
- `previewAudioUrl: String` — Audio stream URL for auditioning.
- `stemPackage: BeatStemPackage` — Stem configuration and availability.
- `salesRecords: List<BeatSaleRecord>` — Historical ledger of completed licensing transactions.
- `auditionCount: int` — Total audition preview plays.
- `createdAt: DateTime` — Immutable creation timestamp.
- `updatedAt: DateTime` — Mutable modification timestamp.

### REQ-BEAT-02 — Beat Status Enum
The system **MUST** define a `BeatStatus` enum with values:
- `draft` — Vault only, not visible on the public marketplace.
- `published` — Actively listed and purchasable in the Beats Marketplace (`/market`).
- `archived` — Inactive, hidden from both marketplace and standard vault view unless filtered.
Each value **MUST** expose:
- `label: String` (`'Draft'`, `'Published'`, `'Archived'`).
- `toJson() → String` (snake_case representation).
- `BeatStatus.fromJson(String) → BeatStatus` factory with fallback to `draft`.

### REQ-BEAT-03 — Beat License Tier Enum
The system **MUST** define a `BeatLicenseTier` enum with values:
- `nonExclusiveCommercial` — Standard commercial release right.
- `exclusiveOwnership` — Full buyout and exclusive transfer of master rights.
- `syncLicense` — TV, film, gaming, and commercial advertising broadcast rights.
- `personalLease` — Non-commercial evaluation and demo recording lease.
Each value **MUST** expose:
- `label: String` (`'Non-Exclusive Commercial'`, `'Exclusive Ownership'`, `'Sync License'`, `'Personal Lease'`).
- `defaultPriceCredits: int` (10, 50, 30, 5).
- `toJson() → String` and `BeatLicenseTier.fromJson(String)` factory.

### REQ-BEAT-04 — Beat Stem Package Value Object
The system **MUST** define an immutable `BeatStemPackage` value object with fields:
- `drumsUrl: String?`
- `bassUrl: String?`
- `melodyUrl: String?`
- `otherUrl: String?`
- `isSeparated: bool` — Whether stems have been generated or uploaded.
- Computed `stemCount: int` returning the count of non-null stem URLs.
- `hasAllStems: bool` returning `true` when all 4 stem URLs are non-null.

### REQ-BEAT-05 — Beat Sale Record Value Object
The system **MUST** define an immutable `BeatSaleRecord` value object with fields:
- `saleId: String` — Transaction identifier.
- `buyerId: String` — Buyer user identifier.
- `buyerHandle: String` — Buyer public handle.
- `licenseTier: BeatLicenseTier` — License tier purchased.
- `creditsEarned: int` — Credits credited to the producer.
- `timestamp: DateTime` — Date and time of sale.

### REQ-BEAT-06 — Computed Properties & Serialization
`ProducerBeatEntity` **MUST** expose:
- `isPublished: bool` (`status == BeatStatus.published`).
- `totalSales: int` (`salesRecords.length`).
- `totalEarningsCredits: int` (sum of `salesRecords.creditsEarned`).
- `bpmLabel: String` (`'$bpm BPM'`).
- `priceLabel: String` (`'⚡ $priceInCredits Credits'`).
- `keyLabel: String` (`musicalKey.isEmpty ? 'Unknown Key' : musicalKey`).
- Full JSON serialization (`toJson()` and `fromJson()`), `copyWith()`, `operator ==`, and `hashCode`.

---

## 2. Repository Requirements

### REQ-BEAT-07 — `IBeatRepository` Interface
The system **MUST** define `IBeatRepository` in `lib/features/beats/domain/repositories/i_beat_repository.dart` with:
- `getAllBeats() → Future<List<ProducerBeatEntity>>` (newest-first).
- `getBeatById(String id) → Future<ProducerBeatEntity?>`.
- `saveBeat(ProducerBeatEntity beat) → Future<void>` (upsert).
- `deleteBeat(String id) → Future<void>` (idempotent).
- `publishBeat(String id) → Future<ProducerBeatEntity>`.
- `unpublishBeat(String id) → Future<ProducerBeatEntity>`.
- `recordSale(String id, BeatSaleRecord sale) → Future<ProducerBeatEntity>`.
- `incrementAuditions(String id) → Future<ProducerBeatEntity>`.
- `clearAll() → Future<void>`.

### REQ-BEAT-08 — `InMemoryBeatRepository`
The system **MUST** implement `InMemoryBeatRepository` in `lib/features/beats/data/repositories/in_memory_beat_repository.dart` pre-seeded with at least 3 realistic African producer beats (e.g. Amapiano, Gqom, Kwaito) for headless unit testing.

### REQ-BEAT-09 — `BeatRepository` (Hive-Backed)
The system **MUST** implement `BeatRepository` in `lib/features/beats/data/repositories/beat_repository.dart`:
- It **MUST** store entities as JSON maps in `AppConstants.beatsBoxKey = 'vhunambi_beats'`.
- It **MUST** check `Hive.isBoxOpen(AppConstants.beatsBoxKey)` before access and silently fall back to an internal memory map if Hive is uninitialized to ensure 100% headless test safety.

---

## 3. State Management Requirements

### REQ-BEAT-10 — `BeatsNotifier` & Provider
The system **MUST** provide `beatsProvider` in `lib/features/beats/presentation/providers/beats_provider.dart` via `StateNotifierProvider<BeatsNotifier, List<ProducerBeatEntity>>` exposing:
- `loadBeats() → Future<void>`
- `createBeat(...) → Future<ProducerBeatEntity>`
- `updateBeat(ProducerBeatEntity beat) → Future<void>`
- `deleteBeat(String id) → Future<void>`
- `publishToMarket(String id) → Future<void>`
- `unpublishFromMarket(String id) → Future<void>`
- `recordSale(String id, String buyerHandle, int credits, BeatLicenseTier tier) → Future<void>`
- `recordAudition(String id) → Future<void>`
- `convertTrackToBeat(LibraryTrack track, {int bpm, String key, int price}) → Future<ProducerBeatEntity>`

### REQ-BEAT-11 — Beats Vault Filter State & Provider
The system **MUST** provide `beatsVaultFilterProvider` (`StateProvider<BeatsVaultFilterState>`) managing:
- `searchQuery: String` (filters title, genre, key, tags).
- `statusFilter: BeatStatus?` (`null` for All, or specific status).
- `genreFilter: String?` (specific genre or `'All'`).
- `sortOrder: BeatsSortOrder` (`newest`, `bpmAsc`, `bpmDesc`, `mostSales`, `highestEarnings`).

### REQ-BEAT-12 — Filtered Beats Projection
The system **MUST** provide `filteredBeatsVaultProvider` (`Provider<List<ProducerBeatEntity>>`) returning sorted and filtered beats.

### REQ-BEAT-13 — Producer Stats Projection
The system **MUST** provide `beatsVaultStatsProvider` (`Provider<BeatsVaultStats>`) calculating:
- `totalBeats: int`
- `publishedCount: int`
- `draftCount: int`
- `totalSalesCount: int`
- `totalCreditsEarned: int`

---

## 4. UI Presentation Requirements

### REQ-BEAT-14 — `BeatsVaultView` Scaffolding
The system **MUST** implement `BeatsVaultView` in `lib/features/beats/presentation/views/beats_vault_view.dart`:
- It **MUST** be mounted in `LibraryView` when `category == LibraryCategory.beats`.
- It **MUST** display `BeatStatsBanner` at the top.
- It **MUST** display an action bar with search field, status filter chips (`All`, `Published`, `Draft`), view mode toggle (`Grid` / `List`), and `+ New Beat` primary CTA.
- If no beats match, it **MUST** display an empty state with a call-to-action to create or convert a beat.
- In grid mode, it **MUST** render responsive cards (2 cols mobile, 3 cols tablet, 4 cols desktop).
- In list mode, it **MUST** render `Material`-wrapped `BeatListTile` rows.

### REQ-BEAT-15 — `BeatCard` Grid Presentation
The system **MUST** implement `BeatCard` displaying:
- Dynamic regional genre gradient header.
- Top badges: BPM pill and Musical Key pill.
- Status badge (`BeatStatusBadge`).
- Beat title and producer handle.
- Price tag in credits and sales counter (`'⚡ 10 Cr • 5 sold'`).
- Audio preview play button (routes to persistent player).
- Overflow `⋮` action menu (Edit, Publish/Unpublish, Export Stems, Delete).

### REQ-BEAT-16 — `BeatListTile` List Presentation
The system **MUST** implement `BeatListTile` wrapped in `Material`:
- 48×48px genre squircle with play/pause audition trigger.
- Title and subtitle (`'Amapiano • 112 BPM • F# Minor'`).
- Price chip and Status badge.
- Inline Publish/Draft toggle switch.
- Trailing `⋮` menu.

### REQ-BEAT-17 — `BeatDetailCockpitView`
The system **MUST** implement `BeatDetailCockpitView` in `lib/features/beats/presentation/views/beat_detail_cockpit_view.dart`:
- Header: Back navigation, title, overflow menu.
- Hero Section: 160×160px artwork with genre gradient, title, producer byline, metadata tags, and `[▶ Audition Preview]` CTA.
- Marketplace Status Card: Live status banner, price in credits, license tier, total sales, credits earned, and one-tap `[Publish to Marketplace]` / `[Switch to Draft]` button.
- Stems Package Card: 4-stem availability indicators, stem auditioning, and `[⭳ Export Stems Bundle]` CTA.
- Sales & Royalty History: Chronological table/list of completed license purchases with buyer handle, date, and `+⚡ XX credits`.

---

## 5. Modal & Dialog Requirements

### REQ-BEAT-18 — `BeatFormDialog`
The system **MUST** implement `BeatFormDialog` for creating or editing a beat:
- Fields for Title, Genre (dropdown), BPM (number input with tap-tempo and slider), Musical Key (dropdown), Tags (comma-separated), Price in Credits (dropdown/number), and License Tier (dropdown).
- Submit disabled while Title is blank.

### REQ-BEAT-19 — `PublishBeatModal`
The system **MUST** implement `PublishBeatModal` displaying:
- Beat summary (Title, Genre, BPM, Price).
- Explanation of 180s preview streaming and 100% royalty credit terms.
- Confirmation button that triggers `publishToMarket(beat.id)`.

### REQ-BEAT-20 — `StemExportModal`
The system **MUST** implement `StemExportModal` displaying:
- Manifest of 4 stem tracks (Drums, Bass, Melody, Other).
- Individual download simulation buttons and `[Download Full ZIP Manifest]` action.

---

## 6. Integration & Cross-Subsystem Requirements

### REQ-BEAT-21 — Marketplace Cross-Synchronization
When a beat is published via `publishToMarket`:
- It **MUST** inject a corresponding `BeatListingEntity` into `marketplaceBeatsProvider.notifier.addListing(...)`.
- When unpublished, it **MUST** be removed from public marketplace listings.

### REQ-BEAT-22 — Audio Player Bridge
Tapping audition on any beat **MUST** call:
`ref.read(playerStateProvider.notifier).playTrack(track)` with duration set to 180s preview length and `isInstrumental: true`.

### REQ-BEAT-23 — Library View Mounting
`LibraryView` (`lib/features/library/presentation/views/library_view.dart`) **MUST** render `BeatsVaultView(onCreateRequested: onCreateRequested)` whenever `category == LibraryCategory.beats`.

---

## 7. Quality & Verification Gates

### REQ-BEAT-24 — Test Suite Coverage
The Phase 14 implementation **MUST** include at least 35 new automated tests across:
- `test/features/beats/domain/models/producer_beat_entity_test.dart`
- `test/features/beats/data/repositories/beat_repository_test.dart`
- `test/features/beats/presentation/providers/beats_provider_test.dart`
- `test/features/beats/presentation/views/beats_vault_view_test.dart`
- `test/features/beats/presentation/views/beat_detail_cockpit_view_test.dart`

### REQ-BEAT-25 — Static Analysis & Regression Gate
- `dart analyze .` **MUST** report **0 issues**.
- `flutter test --no-pub` **MUST** pass **100%** with target **≥ 576 tests** (baseline: 541 passing).
