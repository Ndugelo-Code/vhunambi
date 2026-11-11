# Phase 58 Execution Tasks: Sovereign Beatstore Licensing, Cryptographic Certificates & Automated Vault Stem Delivery

```
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
  VHUNAMBI ENGINEERING TASK ROADMAP & VERIFICATION CHECKLIST
  PHASE 58: SOVEREIGN BEATSTORE LICENSING & REAL CHECKOUT FLOW
  STANDARD: ALL-GEMINI HARDENED SPECIFICATION (STD-SPEC-001 / STD-UIUX-001)
  TARGET PACKAGES: apps/vhunambi_client & apps/vhunambi_api
  PARENT BLUEPRINT: docs/phases/phase_58_sovereign_beatstore_licensing/blueprint.md
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        PHASE 58 MILESTONE ROADMAP & DEPENDENCY GRAPH                             │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                  │
│  [M58.1: Pure Dart Multi-Tier Licensing Engine & FIPS 180-4 SHA-256 Certificate Signer]          │
│  └── licensing_models.dart, license_agreement_engine.dart, sovereign_certificate_signer.dart     │
│            │                                                                                     │
│            ▼                                                                                     │
│  [M58.2: Hive Certificate Vault, 44.1 kHz Master/Stem Unpacker & Legal Deed Exporter]            │
│  └── app_constants.dart, license_certificate_repository.dart, beat_delivery_unpacker_service.dart│
│      certificate_share_exporter.dart, http_marketplace_repository.dart                           │
│            │                                                                                     │
│            ▼                                                                                     │
│  [M58.3: Shared Entity Extensions, Wallet Reconciliation & Riverpod Checkout Orchestrator]       │
│  └── library_models.dart, library_providers.dart, marketplace_models.dart,                       │
│      producer_beat_entity.dart, beats_provider.dart, creator_wallet_provider.dart,               │
│      marketplace_providers.dart, beat_checkout_provider.dart                                     │
│            │                                                                                     │
│            ▼                                                                                     │
│  [M58.4: Multi-Tier Checkout HUD, Certificate Deed Sheet, Top-Bar Coin Unification & Vault Wire] │
│  └── marketplace_top_bar.dart, marketplace_view.dart, beat_card.dart, beat_license_modal.dart,   │
│      license_certificate_sheet.dart, track_actions_sheet.dart, beats_vault_view.dart,            │
│      reference_audio_dropzone.dart                                                               │
│            │                                                                                     │
│            ▼                                                                                     │
│  [M58.5: Backend SQLite WAL ACID Checkout, Exclusive Buyout Lock & Sync Integration]             │
│  └── vhunambi_db.ts, marketplace_types.ts, marketplace_service.ts, marketplace_routes.ts         │
│            │                                                                                     │
│            ▼                                                                                     │
│  [M58.6: Automated Client & API Test Suites, Legacy Compatibility Audit & Build Verification]    │
│  └── phase58_licensing_domain_test.dart, phase58_delivery_unpacker_test.dart,                    │
│      phase58_checkout_widget_test.dart, marketplace_view_test.dart, marketplace_phase58.test.ts  │
│                                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Focus Area | Primary Target Files | Dependencies |
| :---: | :--- | :--- | :---: |
| **M58.1** | Pure Dart Tiers & SHA-256 Signer | `licensing_models.dart`, `license_agreement_engine.dart`, `sovereign_certificate_signer.dart` | None |
| **M58.2** | Hive Cert Store, Unpacker & Exporter | `license_certificate_repository.dart`, `beat_delivery_unpacker_service.dart`, `certificate_share_exporter.dart`, `http_marketplace_repository.dart` | M58.1 |
| **M58.3** | Models, Wallet & Checkout Notifier | `library_models.dart`, `creator_wallet_provider.dart`, `beat_checkout_provider.dart`, `marketplace_providers.dart` | M58.1, M58.2 |
| **M58.4** | Checkout Modal, Deed Sheet & Stems | `marketplace_top_bar.dart`, `beat_license_modal.dart`, `license_certificate_sheet.dart`, `track_actions_sheet.dart`, `beats_vault_view.dart` | M58.3 |
| **M58.5** | SQLite ACID Lock & API Endpoints | `vhunambi_db.ts`, `marketplace_types.ts`, `marketplace_service.ts`, `marketplace_routes.ts` | M58.1 |
| **M58.6** | Automated Verification & Regression | Client & API Phase 58 test suites + `dart analyze` + TypeScript checks | M58.1–M58.5 |

---

## 2. Granular Task Checklist

### Milestone M58.1: Pure Dart Multi-Tier Licensing Engine & Cryptographic Signer

- [x] **Task 58.1.1 (`REQ-P58-LIC-01`, `REQ-P58-LIC-04`):** Create `apps/vhunambi_client/lib/features/marketplace/domain/models/licensing_models.dart`:
  - Define constants `kCoinsPerCredit = 5`, `kZarPerCoin = 0.30`, `kProducerRoyaltyPercent = 85`, `kPlatformFeePercent = 15`.
  - Implement `BeatCheckoutTier` (`basicMp3`, `premiumWav`, `exclusiveStem`) with multipliers `1 / 3 / 6`, wire slugs (`basic_lease`, `stems_trackout`, `exclusive_stem`), `fromWire(...)` supporting Phase 14/28 legacy slugs (`'exclusive'`, `'unlimited_commercial'`, `'stems_trackout'`, `'basic_lease'`), and entitlement properties.
  - Implement immutable value types `LicenseTierPricing`, `LicenseRightsProfile`, `UnpackedBeatPackage`, `SovereignLicenseCertificate` (with `toJson()`/`fromJson()`/`copyWith()`), `CheckoutPhase`, and `BeatCheckoutState`.
  - **Acceptance Criteria**: Zero `flutter` UI imports in domain files; full value equality verified in unit tests.

- [x] **Task 58.1.2 (`REQ-P58-LIC-02`, `REQ-P58-LIC-03`):** Create `apps/vhunambi_client/lib/features/marketplace/domain/services/license_agreement_engine.dart`:
  - Implement `calculateTierPricing` enforcing $C_{\text{prod}} = (C_{\text{gross}} \times 85 + 50) \div 100$ and $C_{\text{plat}} = C_{\text{gross}} - C_{\text{prod}}$ so Coin & ZAR conservation holds identically for all credit values.
  - Implement `evaluateAffordability` and `buildRightsProfile` producing tier bullet clauses and full legal deed text.
  - **Acceptance Criteria**: Integer split conservation verified across edge inputs (`1`, `5`, `7`, `13`, `99` Credits).

- [x] **Task 58.1.3 (`REQ-P58-CERT-01`, `REQ-P58-CERT-02`):** Create `apps/vhunambi_client/lib/features/marketplace/domain/services/sovereign_certificate_signer.dart`:
  - Implement `buildCanonicalPreimage` (`VHUNAMBI_LIC_V2|...`) and `sha256HexUtf8` / `sha256HexBytes` backed solely by `VaultEnvelopeCrypto.sha256Bytes` (no new `pubspec.yaml` dependencies).
  - Implement `generateCertificateId`, `signCertificate`, and offline `verifyIntegrity(SovereignLicenseCertificate)`.
  - **Acceptance Criteria**: Produces 64-char lowercase hex matching NIST SHA-256 vectors; 1-character tamper flips `verifyIntegrity` to `false`.

---

### Milestone M58.2: Hive Certificate Vault, 44.1 kHz Master/Stem Unpacker & Deed Exporter

- [x] **Task 58.2.1 (`REQ-P58-CERT-03`):** Update `apps/vhunambi_client/lib/core/constants/app_constants.dart` and create `apps/vhunambi_client/lib/features/marketplace/data/repositories/license_certificate_repository.dart`:
  - Add `AppConstants.licenseCertificatesBoxKey = 'vhunambi_license_certificates'`.
  - Implement Hive persistence with `FLUTTER_TEST` & uninitialized-Hive in-memory fallback (`_memory` map) and lookup by `certificateId`, `beatId`, and `vaultTrackId`.
  - **Acceptance Criteria**: Zero Hive lock/init crashes under headless `flutter test`.

- [x] **Task 58.2.2 (`REQ-P58-DEL-01`, `REQ-P58-DEL-02`, `REQ-P58-DEL-03`):** Create `apps/vhunambi_client/lib/features/marketplace/data/services/beat_delivery_unpacker_service.dart`:
  - Resolve `<vaultAudioDir>/licensed/<beatId>/` using `IOfflineStorageService.resolveVaultAudioDirectory()` and `normalizeWritablePath(...)`.
  - Attempt `Dio` remote fetch when reachable on real URLs; otherwise synthesize deterministic genre-, key-, and BPM-matched `44.1 kHz` 16-bit Stereo PCM RIFF/WAVE files via `MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes` and persist via `writeWavToFile`.
  - Deliver `untagged_master.wav` (`basicMp3`), `master_44k1.wav` (`premiumWav`), or `master_44k1.wav` + all 4 isolated stems (`drums_44k1.wav`, `bass_44k1.wav`, `melody_44k1.wav`, `other_44k1.wav`) (`exclusiveStem`).
  - **Acceptance Criteria**: Physical files exist on disk with valid 44-byte RIFF/`WAVE` headers and SHA-256 master hash matches `SovereignLicenseCertificate.masterFileSha256`.

- [x] **Task 58.2.3 (`REQ-P58-CERT-04`):** Create `apps/vhunambi_client/lib/features/marketplace/data/services/certificate_share_exporter.dart` and update `apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart`:
  - Export `<certificateId>.vhlic.json` and `<certificateId>_DEED.txt` and share via `Share.shareXFiles` (`package:share_plus/share_plus.dart`).
  - Replace `'hash_simulated_...'` fallback in `HttpMarketplaceRepository.licenseBeat` with `SovereignCertificateSigner` SHA-256 digest and parse HTTP `402` / `409` responses cleanly.
  - **Acceptance Criteria**: Exported `.vhlic.json` and `_DEED.txt` are written and non-empty; zero simulated hash strings remain.

---

### Milestone M58.3: Shared Entities, Wallet Reconciliation & Riverpod Checkout Orchestrator

- [x] **Task 58.3.1 (`REQ-P58-DEL-04`):** Update `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart` and `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`:
  - Add optional additive fields `licenseCertificateIdOverride`, `licenseHash`, `licenseTierId`, `masterAudioFilePath`, `stemPaths` to `LibraryTrack` (updating `copyWith`, `==`, `hashCode`, `licenseCertificateId`, and `toTrack()` preferring `masterAudioFilePath ?? localAudioFilePath ?? remoteAudioUrl`).
  - Add `LibraryTracksNotifier.upsertLicensedTrack(LibraryTrack track)` to insert or cleanly upgrade existing vaulted licenses without duplicating rows.

- [x] **Task 58.3.2 (`REQ-P58-LIC-05`, `REQ-P58-CHK-04`):** Update `marketplace_models.dart`, `producer_beat_entity.dart`, and `beats_provider.dart`:
  - Add `isExclusiveSold` (`false`), `exclusiveBuyerId` (`null`), `availableTiers`, `baseCoins`, `baseZar` to `BeatListingEntity`.
  - Add `isExclusiveSold` (`false`), `exclusiveBuyerId` (`null`) to `ProducerBeatEntity` with full JSON serialization parity.
  - Extend `BeatsNotifier.recordSale(..., {String? markExclusiveBuyerId})` and `MarketplaceBeatsNotifier.markSoldExclusive(...)`; filter `beat.isExclusiveSold` out of public `filterBeats(...)` listings.

- [x] **Task 58.3.3 (`REQ-P58-CHK-02`, `REQ-P58-CHK-03`, `REQ-P58-CHK-05`):** Update `creator_wallet_provider.dart`, create `beat_checkout_provider.dart`, and update `marketplace_providers.dart`:
  - Add `CreatorWalletNotifier.debitForBeatPurchase(...)` and `refundCoins(...)`.
  - Implement `BeatCheckoutNotifier` (`beatCheckoutProvider`), `LicenseCertificatesNotifier` (`licenseCertificatesProvider`), and dependencies.
  - Ensure unpacking failure refunds Coins cleanly (`rolledBack: true`) and successful checkouts enqueue `SyncMutationRecord` (`priority: SyncPriority.critical`, `entityType: 'beat_license'`, `action: 'purchase'`).
  - Keep synchronous compatibility `licenseBeat(WidgetRef ref, BeatListingEntity beat)` working for Phase 39 & Phase 40 regression tests while issuing a real FIPS 180-4 SHA-256 certificate and debiting Coin balance.

---

### Milestone M58.4: Multi-Tier Checkout Modal, Deed Sheet, Top-Bar Coin Unification & Vault/Studio Wiring

- [x] **Task 58.4.1 (`REQ-P58-CHK-01`):** Update `marketplace_top_bar.dart`, `marketplace_view.dart`, and `beat_card.dart`:
  - Replace `_CreditChip` in `MarketplaceTopBar` with `const VhunambiUserCoinsChip()`.
  - Pass `onNavigateToLibrary` into `showBeatLicenseModal(...)` in `MarketplaceView`.
  - Surface Coins + ZAR pricing subtitle on `BeatCard` alongside existing credit badge.

- [x] **Task 58.4.2 (`REQ-P58-CHK-02`, `REQ-P58-UI-01`):** Refactor `apps/vhunambi_client/lib/features/marketplace/presentation/widgets/beat_license_modal.dart`:
  - Render 3 interactive tier cards (`Key('license_tier_card_basicMp3')`, `Key('license_tier_card_premiumWav')`, `Key('license_tier_card_exclusiveStem')`).
  - Render expandable full agreement prose (`Key('license_expand_terms_btn')`), Coin/ZAR split breakdown, inline deficit warning + `Key('checkout_topup_btn')` calling `SubscriptionUpgradeModal.show(context)`, `Key('checkout_confirm_btn')`, and Verified Ownership Receipt with `Key('checkout_view_cert_btn')` & `Key('checkout_open_vault_btn')`.
  - Eliminate stock Material `Icons.check_circle_rounded`; use Phosphor `AppIcons.*` tokens only.

- [x] **Task 58.4.3 (`REQ-P58-CERT-04`):** Create `apps/vhunambi_client/lib/features/marketplace/presentation/widgets/license_certificate_sheet.dart` and refactor `track_actions_sheet.dart`:
  - Replace the stub `"PDF export ... ships with the licensing release"` SnackBar in `showLibraryLicenseDialog` with `showLicenseCertificateSheet(context, track: track)`.
  - Preserve `Key('track_action_list_in_beatstore')` and its legacy `List in Beatstore` row untouched so `phase28_marketplace_vault_bridge_test.dart` stays green.

- [x] **Task 58.4.4 (`REQ-P58-DEL-05`):** Update `beats_vault_view.dart` and `reference_audio_dropzone.dart`:
  - Add `Key('licensed_beat_stems_btn_${track.id}')` to `_LicensedBeatCard` whenever `track.stemPaths.isNotEmpty`, opening a 4-stem audition & export drawer (`drums`, `bass`, `melody`, `other`).
  - Update `ReferenceAudioDropzone._showBeatPicker` so licensed Vault tracks (and their local `masterAudioFilePath`) appear alongside produced beats.

---

### Milestone M58.5: Backend SQLite WAL ACID Checkout & API Hardening (`apps/vhunambi_api`)

- [x] **Task 58.5.1 (`REQ-P58-API-01`, `REQ-P58-API-02`, `REQ-P58-API-04`):** Update `apps/vhunambi_api/src/db/vhunambi_db.ts`:
  - Create `beat_licenses` table and ensure `marketplace_assets` supports `is_exclusive_sold` and `exclusive_buyer_id`.
  - Implement `recordBeatLicenseAtomic(...)` with `BEGIN IMMEDIATE` SQLite transaction, identical `VHUNAMBI_LIC_V2|...` SHA-256 hash generation via `node:crypto`, `exclusive_conflict` / `insufficient_funds` guards, `wallet_ledger` debit/credit rows, and `applyMutationsBatch` support for `entityType: 'beat_license'`.
  - Implement `verifyBeatLicense(certificateId)` & `getBeatLicensesByBuyer(buyerId)`.

- [x] **Task 58.5.2 (`REQ-P58-API-02`, `REQ-P58-API-03`):** Update `marketplace_types.ts`, `marketplace_service.ts`, and `marketplace_routes.ts`:
  - Add `'exclusive_stem'`, `isExclusiveSold`, `exclusiveBuyerId` to types & seed listings.
  - Route `POST /api/marketplace/beats/:id/license` through `vhunambiDb.recordBeatLicenseAtomic(...)`, returning `409 Conflict` when already exclusively sold and `402` when insufficient server balance.
  - Add `GET /api/marketplace/licenses/verify/:certificateId`.

---

### Milestone M58.6: Automated Verification Suites, Legacy Compatibility & Release Build

- [x] **Task 58.6.1:** Create `apps/vhunambi_client/test/features/marketplace/phase58_licensing_domain_test.dart`:
  - Verify `1x / 3x / 6x` tier pricing & exact integer Coin/ZAR 85/15 conservation splits.
  - Verify `SovereignCertificateSigner` FIPS 180-4 SHA-256 digests and 1-char tamper invalidation.
  - Verify `BeatCheckoutTier.fromWire(...)` backward compatibility.

- [x] **Task 58.6.2:** Create `apps/vhunambi_client/test/features/marketplace/phase58_delivery_unpacker_test.dart` & checkout orchestrator tests:
  - Verify real un-tagged `44.1 kHz` RIFF/WAV master (`basicMp3`, `premiumWav`) and 4-stem WAV files (`drums`, `bass`, `melody`, `other` for `exclusiveStem`) exist cleanly on temp disk with valid RIFF headers.
  - Verify buyer Coin debit, conditional royalty guard, rollback refund upon injected file-writer exception, Exclusive Lock (`isExclusiveSold == true` filtering future discovery), and critical `SyncOutboxService` enqueueing.

- [x] **Task 58.6.3:** Create `apps/vhunambi_client/test/features/marketplace/phase58_checkout_widget_test.dart`:
  - Verify 3 tier cards toggle price & terms, insufficient funds renders `Key('checkout_topup_btn')` and updates live when top-up Coins are added, successful exclusive checkout transitions to Verified Receipt, opens `LicenseCertificateSheet` (`Key('license_cert_verify_btn')`, `Key('license_cert_share_btn')`), and shows Stems drawer in `BeatsVaultView`.

- [x] **Task 58.6.4 (Compatibility & Regression Audit):**
  - Update `apps/vhunambi_client/test/features/marketplace/marketplace_view_test.dart` for unified `VhunambiUserCoinsChip` (`250 Coins` default) and multi-tier modal CTA flow.
  - Reconcile pre-existing `_seedBeats()` count expectations in `marketplace_notifier_test.dart` (`category: all` vs `category: beats`).
  - Confirm ZERO regressions in `phase28_marketplace_vault_bridge_test.dart`, `phase39_identity_discovery_and_talent_market_test.dart`, and `phase40_notifications_lexicon_cosign_and_topup_test.dart`.

- [x] **Task 58.6.5:** Add backend SQLite & route integration tests in `apps/vhunambi_api` verifying ACID debit/credit split, `beat_licenses` persistence, `GET /api/marketplace/licenses/verify/:certificateId`, and HTTP `409 Conflict` on duplicate exclusive purchase.

---

## 3. Mandatory Anti-Trap Verification Checklist (`STD-SPEC-001`)

| # | Trap Guardrail | Verification Target | Status Target |
| :---: | :--- | :--- | :---: |
| **1** | **Correct Package Prefix** | Only `package:vhunambi_client/...` (zero `package:zania_app` or invented packages) | Required |
| **2** | **Verified Dependencies** | Zero new entries added to `pubspec.yaml` (SHA-256 via `VaultEnvelopeCrypto.sha256Bytes`; share via `share_plus`) | Required |
| **3** | **Verified Phosphor & Color Tokens** | Only `package:phosphor_icons/phosphor_icons.dart`, `AppIcons.*`, and existing `AppColors.*` / `AppTypography.*` getters | Required |
| **4** | **Deterministic Widget Keys** | Every tier card, confirm btn, top-up btn, cert verify/copy/share btn, and stem drawer btn carries explicit `Key('...')` | Required |
| **5** | **100% Spec-to-Code Parity** | Tokenomics (`1 Credit = 5 Coins`, `R0.30/Coin`, `1x/3x/6x`, 85/15 split) and `VHUNAMBI_LIC_V2` SHA-256 preimage match across Flutter & API | Required |
| **6** | **Zero Raw Emojis (`STD-UIUX-001`)** | Zero raw Unicode emoji strings in Phase 58 Dart widgets, TS responses, or formal spec tables | Required |
| **7** | **Headless & Regression Safety** | Hive fallback active in `FLUTTER_TEST`; `Directory.systemTemp` file IO safe; Phase 28/39/40 tests remain 100% green | Required |

---

## 4. Stage 4 Verification Commands (Do NOT Run During Spec Drafting!)

When ready to execute Stage 4 implementation against this spec:

```powershell
# 1. Static Analysis (Flutter Client)
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze lib/ test/

# 2. Targeted Phase 58 + Compatibility Tests
flutter test `
  test/features/marketplace/ `
  test/features/explore/phase39_identity_discovery_and_talent_market_test.dart `
  test/features/explore/phase40_notifications_lexicon_cosign_and_topup_test.dart

# 3. Full Client Regression Test Suite
flutter test

# 4. Backend TypeScript Build & Tests
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npm run build
npm test
```
