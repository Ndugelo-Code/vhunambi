# Phase 14 · Walkthrough — Producer Beats Vault & Beatstore Listing Cockpit

> **Phase:** 14
> **Codename:** `beats-vault`
> **Standard:** RFC 2119 / EARS (see `requirements.md`)
> **Executed By:** Cline (Dual-Agent Symbiosis Protocol)
> **Verification:** `dart analyze .` = **0 issues** · `flutter test --no-pub` = **627/627 passing (100%)**

---

## 1. Executive Summary

Phase 14 closes the `/library?tab=beats` deferred loop from Phase 4 by shipping the **Producer Beats Vault** — a producer-side beatstore cockpit that authors, licenses and publishes instrumental beats while mirroring every publication change into the Phase 6 marketplace:

1. **Domain layer (`producer_beat_entity.dart`)**:
   * `BeatStatus` enum (`draft`, `published`, `archived`) with `label`, `toJson()`, tolerant `fromJson()` (defaults to `draft`).
   * `BeatLicenseTier` enum (`nonExclusiveCommercial`, `exclusiveOwnership`, `syncLicense`, `personalLease`) with `label`, `defaultPriceCredits` (10 / 50 / 30 / 5), `toJson()` and a case-tolerant `fromJson()` with a non-exclusive fallback.
   * `BeatStemPackage` value object (`drumsUrl`, `bassUrl`, `melodyUrl`, `otherUrl`, `isSeparated`) exposing `stemCount`, `hasAllStems`, `stemCountLabel` (`N/4 stems`), `copyWith`, JSON and structural equality.
   * `BeatSaleRecord` royalty-ledger entry (`saleId`, `buyerId`, `buyerHandle`, `licenseTier`, `creditsEarned`, `timestamp`) with `creditsLabel` (`+⚡ 10 Credits`), `dateLabel`, JSON and equality.
   * `ProducerBeatEntity` aggregate with 17 stored fields plus `isPublished` / `isDraft` / `isArchived`, `totalSales`, `totalEarningsCredits`, `bpmLabel`, `priceLabel`, `statusLabel`, `keyLabel` (blank key → `Unknown Key`), `metadataLabel`, `salesLabel`, `createdAgoLabel`, `previewSeconds = 180`, `copyWith`, snake_case JSON and structural equality.

2. **Persistence (`IBeatRepository` + two implementations)**:
   * `InMemoryBeatRepository` — seeded double (3 realistic African beats), newest-`createdAt`-first ordering, explicit `seed` (including `const []`) for empty-state widget tests, `StateError` on unknown-id mutations.
   * `BeatRepository` — Hive-backed (`AppConstants.beatsBoxKey = 'vhunambi_beats'`) storing JSON maps, with a silent in-memory fallback whenever the box is closed (headless `flutter_test` safety, mirrors `PlaylistRepository` / `CollectionRepository`).

3. **State (`beats_provider.dart`)**:
   * `beatsProvider` (`StateNotifierProvider`) over a 14-method `BeatsNotifier`: `loadBeats`, `createBeat` (`beat_<microseconds>`, trimmed title/genre/key, `40–260` BPM clamp, `unmodifiable` tags), `updateBeat`, `deleteBeat`, `publishToMarket`, `unpublishFromMarket`, `archiveBeat`, `restoreToDraft`, `recordSale`, `recordAudition`, `convertTrackToBeat`, `beatById`.
   * Real-time filter projection: `BeatsVaultFilterState` (search + status + genre + `BeatsSortOrder`), `filterBeatsVault` (status → genre → free-text spanning title/genre/key/handle/tags → 5 orderings) and `beatsVaultStatsFor` / `BeatsVaultStats` (totals, live listings, licenses sold, credits earned, `vaultOnlyCount`).
   * Marketplace bridge: `beatListingFromEntity` projects a beat into `BeatListingEntity` (tier label, derived `stemZipUrl` when all four stems exist); every publish/update injects through `MarketplaceBeatsNotifier.upsertListing` while unpublish/archive/delete call `removeListing`.
   * Player bridge: `beatPreviewTrack` (180s instrumental), `auditionBeatPreview` (play + audition counter) and `isBeatAuditioning` backed by `playerStateProvider`.

4. **Vault UI (`BeatsVaultView`)**:
   * Mounted at `/library?tab=beats` inside `LibraryView`.
   * `BeatStatsBanner` producer cockpit (total beats, live on market, licenses sold, credits earned).
   * Action strip: 240px live search, `All / Published / Draft` chips carrying live counts, sort menu (`Sort: Newest`), grid/list toggle and the `New Beat` pill CTA.
   * Responsive 2 / 3 / 4 column grid (`childAspectRatio` 0.78 / 0.82 / 0.85) of `BeatCard`s (genre gradient artwork, BPM/key pills, status badge, `⚡ N Cr • N Sold` footer, audition trigger, `⋮` menu) plus material-wrapped `BeatListTile` rows with a publish `Switch`.
   * `LibraryEmptyState(category: LibraryCategory.beats)` (CTA opens the authoring dialog) and a `No beats match your filters` reset state.
   * Authoring/editing (`BeatFormDialog`), publish confirmation sheet (`PublishBeatModal`), stems manifest sheet (`StemExportModal`) and a destructive delete confirmation.

5. **Cockpit UI (`BeatDetailCockpitView`)**:
   * Live-resolved beat (survives vault refreshes) with the `Beat unavailable` fallback for deleted ids.
   * AppBar with back chevron, beat title and the `⋮` Edit / Publish / Export / Delete menu.
   * Hero section (160px genre-gradient artwork, BPM/key pills, producer handle, tags, `180s preview • N auditions`, `▶ Audition Preview` / `Edit` / `Export Stems` actions), marketplace status card with the one-tap `Publish to Marketplace` / `Switch to Draft` toggle, stems package card (4 stem indicators + `Export Stems Bundle`) and a royalty ledger row per `BeatSaleRecord` with `+⚡ N Credits`.

6. **Cross-subsystem integration**:
   * `library_view.dart` mounts `BeatsVaultView(onCreateRequested: …)` whenever `LibraryCategory.beats` is active.
   * `marketplace_providers.dart` gained `upsertListing` / `removeListing` so the vault injects and retracts public listings without duplicating seeds; the marketplace `BeatCard` renders vault-authored listings unchanged.

---

## 2. Task Ledger (`tasks.md` → status)

| Task | Deliverable | Status |
| --- | --- | --- |
| 1 | `AppConstants.beatsBoxKey` | ✅ Complete |
| 2 | `producer_beat_entity.dart` (`BeatStatus`, `BeatLicenseTier`, `BeatStemPackage`, `BeatSaleRecord`, `ProducerBeatEntity`) | ✅ Complete |
| 3 | `IBeatRepository` (9-method contract) | ✅ Complete |
| 4 | `InMemoryBeatRepository` + `seedProducerBeats()` | ✅ Complete |
| 5 | `BeatRepository` (Hive + headless fallback) | ✅ Complete |
| 6 | `beats_provider.dart` (providers, filters, stats, notifier, player bridge) | ✅ Complete |
| 7 | `beat_format.dart` (genres, keys, price presets, gradients, BPM clamp, tag parser, preview URL) | ✅ Complete |
| 8 | `beat_status_badge.dart`, `beat_stats_banner.dart`, `beat_card.dart`, `beat_list_tile.dart`, `beat_form_dialog.dart`, `publish_beat_modal.dart`, `stem_export_modal.dart` | ✅ Complete |
| 9 | `BeatsVaultView` (banner, search, chips, sort, toggle, CTA, grid/list, empty + no-match states, dialog/sheet wiring) | ✅ Complete |
| 10 | `BeatDetailCockpitView` (app bar, hero, marketplace card, stems card, royalty ledger) | ✅ Complete |
| 11 | `library_view.dart` mount + marketplace `upsertListing` / `removeListing` bridge | ✅ Complete |
| 12 | Automated suites under `test/features/beats/` (86 tests) | ✅ Complete |
| 13 | Verification gate (`dart analyze .` = 0 issues, `flutter test --no-pub` = 627/627) + walkthrough + handoff docs | ✅ Complete |

---

## 3. Test Inventory (86 new tests)

```
producer_beat_entity_test.dart (25 tests)
  * BeatStatus labels · snake_case serialisation · case-tolerant fromJson fallback
  * BeatLicenseTier contract labels · default credit prices · round-trip + fallback
  * BeatStemPackage empty manifest · stemCount ignores null/empty · hasAllStems · copyWith · JSON
  * BeatSaleRecord credits/date labels · JSON round-trip · structural equality
  * ProducerBeatEntity defaults · publication flags · sales aggregation · label rendering
  * blank key fallback · copyWith · JSON round-trip (stems/tags/ledger) · partial payload defaults
  * structural equality · createdAgoLabel

beat_repository_test.dart (14 tests)
  * InMemory seeding + newest-first order · getBeatById · save/delete · publish/unpublish
  * recordSale ledger append · incrementAuditions · clearAll · unknown-id StateError
  * Hive-backed BeatRepository persistence/rehydration · publish+sale+audition round-trip · clearAll
  * headless in-memory fallback when the box is closed

beats_provider_test.dart (19 tests)
  * notifier load ordering · createBeat clamp/trim/prepend · published create → listing injection
  * idempotent publishToMarket · unpublishFromMarket · archiveBeat / restoreToDraft · deleteBeat
  * recordSale ledger + listing sync · recordAudition counter · convertTrackToBeat
  * unknown-id no-ops · filter state activity/clear semantics · vault stats aggregation
  * listing bridge (`beatListingFromEntity`) · 180s preview track · filter-provider reactivity

beats_widgets_test.dart (14 tests)
  * BeatStatusBadge (all three pills) · BeatStatsBanner metrics
  * BeatCard artwork/metadata/footer + every callback · auditioning icon swap
  * BeatListTile row metadata + publish switch · overflow menu publish/export
  * BeatFormDialog validation gate + payload (BPM clamp, tag de-dupe, publish chip)
  * edit-mode prefill/save · tier → price sync · tap-tempo BPM derivation
  * PublishBeatModal terms + keep-draft/confirm · StemExportModal ready/disabled stems + bundle

beats_vault_view_test.dart (14 tests)
  * empty state + CTA dialog · cockpit banner/chips/grid cards · grid ⇄ list toggle
  * search + no-match reset · status chip scoping · New Beat authoring (preview URL derivation)
  * publish confirmation sheet + marketplace injection · unpublish retraction
  * delete confirmation flow · stems sheet · cockpit hero/marketplace/stems/ledger
  * cockpit publish toggle · cockpit unavailable fallback · `/library?tab=beats` mount
```

---

## 4. Key Design Decisions & Deviations

1. **`BeatLicenseTier.fromJson` normalises the enum name:** the first cut compared `tier.name == value.toLowerCase().trim()`, which silently degraded every camelCase tier (`exclusiveOwnership`, `syncLicense`, `personalLease`) to `nonExclusiveCommercial` whenever a beat was rehydrated from Hive JSON. The implementation now matches `design.md` (`tier.name.toLowerCase() == normalized`), so the domain round-trip suite passes; `BeatStatus.fromJson` was already correct because its names are lowercase.
2. **`BeatsNotifier` uses a redirecting constructor:** `BeatsNotifier({required repository, marketplace}) : this._(repository, marketplace)` forwards to the private positional `BeatsNotifier._(this._repository, this._marketplace)`. The lint `prefer_initializing_formals` rejects `_repository = repository` initializer-list assignments and Dart named parameters cannot be private, so the redirect keeps the public named API (used by `beatsProvider`) while holding `dart analyze .` at 0 issues — the same positional `this._x` convention used by `CollectionsNotifier` / `PlaylistsNotifier`.
3. **One CDN origin:** `beatCdnOrigin` lives beside the seed catalogue (`in_memory_beat_repository.dart`) and is re-exported by `beat_format.dart` as `beatPreviewOrigin`; `beatPreviewUrlFor(title)` slugifies authored titles into `https://cdn.vhunambi.com/beats/<slug>.mp3`, and `beatListingFromEntity` derives `<origin>/stems/<beatId>_stems.zip` only when all four stems exist.
4. **`convertTrackToBeat` reuses `createBeat`:** converting a vault instrumental authors a draft through the same path as the dialog (112 BPM / `F# Minor` / 10 credits / non-exclusive tier, tags seeded from `isInstrumental` + genre) instead of a second persistence route, so every beat shares one clamp/trim/prepend pipeline.
5. **Marketplace sync via `upsertListing` / `removeListing`:** `MarketplaceBeatsNotifier` gained the two mutators so publish/update/archive/delete never duplicate Phase 6 seeds; the marketplace stays the single public listing store and vault mirrors are idempotent.
6. **View-local grid/list preference:** the presentation toggle is `LibraryViewMode` held in `_BeatsVaultViewState` (identical to the Phase 13 collections vault), while search/status/genre/order live in `beatsVaultFilterProvider` so the projection stays reactive and testable without the widget.
7. **Previews are 180s instrumentals:** `beatPreviewTrack` always builds the preview through the persistent player (`language: 'Instrumental'`, `previewSeconds = 180`), `auditionBeatPreview` increments the audition counter, and `isBeatAuditioning` flips play→pause for cards, tiles and the cockpit hero.
8. **Widget-test conventions for modal surfaces:** dialogs/sheets are mounted on real routes (`showDialog` / `showModalBottomSheet`) so the widgets' internal `Navigator.pop()` is exercised; the vault and cockpit suites pump a tree-owned `ProviderScope` and read the container through `ProviderScope.containerOf(...)` so the framework cancels `PlayerNotifier`'s 1s position ticker before the pending-timer assertion (precedent: `queue_drawer_test.dart`).
9. **Phase 4 Beats-tab assertion realigned (not weakened):** `library_view_test.dart` previously asserted song-vault assets on the Beats tab. REQ-BEAT-14 supersedes that stub — the tab mounts `BeatsVaultView`, which reads `beatRepositoryProvider` (empty in a headless run), so the test now locks the vault mount, the `Search my beats...` hint, the `New Beat` CTA and the universal `No beats yet` empty state while still asserting song assets are not leaked into the tab.
10. **Authoring safeguards:** `FilteringTextInputFormatter.digitsOnly`, `clampBeatBpm` (40–260), `parseBeatTags` de-duplication, an injectable `clock` for deterministic tap-tempo tests, and a tier→price preset sync driven by `defaultPriceCredits`.
11. **Null-aware collection element in tests:** `seed: <ProducerBeatEntity>[?beat]` (analyzer `use_null_aware_elements`) keeps the cockpit test helper branch-free.

---

## 5. Files Delivered / Modified

### Created
* `lib/features/beats/domain/models/producer_beat_entity.dart`
* `lib/features/beats/domain/repositories/i_beat_repository.dart`
* `lib/features/beats/data/repositories/in_memory_beat_repository.dart`
* `lib/features/beats/data/repositories/beat_repository.dart`
* `lib/features/beats/presentation/providers/beats_provider.dart`
* `lib/features/beats/presentation/beat_format.dart`
* `lib/features/beats/presentation/views/beats_vault_view.dart`
* `lib/features/beats/presentation/views/beat_detail_cockpit_view.dart`
* `lib/features/beats/presentation/widgets/beat_status_badge.dart`
* `lib/features/beats/presentation/widgets/beat_stats_banner.dart`
* `lib/features/beats/presentation/widgets/beat_card.dart`
* `lib/features/beats/presentation/widgets/beat_list_tile.dart`
* `lib/features/beats/presentation/widgets/beat_form_dialog.dart`
* `lib/features/beats/presentation/widgets/publish_beat_modal.dart`
* `lib/features/beats/presentation/widgets/stem_export_modal.dart`
* `test/features/beats/domain/models/producer_beat_entity_test.dart`
* `test/features/beats/data/repositories/beat_repository_test.dart`
* `test/features/beats/presentation/providers/beats_provider_test.dart`
* `test/features/beats/presentation/widgets/beats_widgets_test.dart`
* `test/features/beats/presentation/views/beats_vault_view_test.dart`
* `docs/phases/phase_14_beats_vault/walkthrough.md`

### Modified
* `lib/core/constants/app_constants.dart` (added `beatsBoxKey`)
* `lib/features/library/presentation/views/library_view.dart` (beats tab mount)
* `lib/features/marketplace/presentation/providers/marketplace_providers.dart` (`upsertListing` / `removeListing`)
* `test/features/library/library_view_test.dart` (Beats-tab assertions realigned to REQ-BEAT-14)

*(all paths relative to `apps/vhunambi_client/`)*

---

## 6. Deferred / Future Work

* Real preview/stem streaming: preview and stem URLs are deterministic CDN paths; waveform previews and audio hosting land with the media pipeline.
* Licence checkout wiring: `recordSale` already accepts ledger entries, but the marketplace licensing flow still records locally.
* Stem separation handoff from the Phase 10 pipeline (`isSeparated` is authored metadata today; the separation lab will populate the four URLs).
* Beat analytics history (auditions/earnings over time) and payout statements.
* Cross-device beat sync (the Hive box is local-only, mirroring the playlist and collection vaults).
