# Phase 58 Requirements Specification: Sovereign Beatstore Licensing, Cryptographic Certificates & Automated Vault Stem Delivery

```
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
  VHUNAMBI REQUIREMENTS SPECIFICATION (STD-SPEC-001 / STD-UIUX-001)
  PHASE 58: SOVEREIGN BEATSTORE LICENSING & REAL CHECKOUT FLOW
  NOTATION: EARS (Easy Approach to Requirements Syntax) & RFC-2119 (MUST / SHALL / SHOULD)
  PARENT BLUEPRINT: docs/phases/phase_58_sovereign_beatstore_licensing/blueprint.md
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## 1. Scope, Currency Standard & Definitions

### 1.1 Commercial Economy Constants
- **Credit-to-Coin Exchange Rate**: `1 Credit = 5 Coins` (`kCoinsPerCredit = 5`).
- **Coin-to-ZAR Valuation**: `1 Coin = R0.30 ZAR` (`kZarPerCoin = 0.30`).
- **Creator-Platform Revenue Split**: **85%** net producer royalty / **15%** platform fee using exact integer Coin conservation ($C_{\text{prod}} + C_{\text{plat}} \equiv C_{\text{gross}}$).

### 1.2 Terminology
- **BeatListingEntity**: Public marketplace catalog item (`apps/vhunambi_client/lib/features/marketplace/domain/models/marketplace_models.dart`).
- **BeatCheckoutTier**: Commercial checkout option selectable during checkout: `basicMp3`, `premiumWav`, or `exclusiveStem`.
- **SovereignLicenseCertificate**: Cryptographically hashed digital ownership deed signed with FIPS 180-4 SHA-256 over a canonical UTF-8 pipe-delimited preimage.
- **UnpackedBeatPackage**: Result of post-purchase file provisioning containing validated local `44.1 kHz` audio paths (`masterPath` and optional `stemPaths` map for `drums`, `bass`, `melody`, `other`), SHA-256 master file digest, and byte size.

---

## 2. Multi-Tier Licensing Agreement Engine (`REQ-P58-LIC`)

- **`REQ-P58-LIC-01` (Canonical Three-Tier Catalog)**:
  - The Marketplace licensing engine MUST define three explicit commercial checkout tiers in pure Dart (`licensing_models.dart`):
    1. **Basic MP3** (`BeatCheckoutTier.basicMp3`, wire slug `basic_lease`, multiplier `1x`).
    2. **Premium WAV** (`BeatCheckoutTier.premiumWav`, wire slug `stems_trackout`, multiplier `3x`).
    3. **Exclusive Stem License** (`BeatCheckoutTier.exclusiveStem`, wire slug `exclusive_stem`, multiplier `6x`).
- **`REQ-P58-LIC-02` (Deterministic Tier Pricing Derivation)**:
  - Given any beat's base listing credits $K_{\text{base}} \ge 1$, `LicenseAgreementEngine.priceForTier(baseCredits: K, tier: t)` SHALL compute exact Coin cost $C_{\text{gross}} = K \times 5 \times m(t)$ where $m(t) \in \{1, 3, 6\}$, and exact two-decimal ZAR cost $Z_{\text{gross}} = \text{round}_2(C_{\text{gross}} \times 0.30)$.
- **`REQ-P58-LIC-03` (Structured Legal Rights Profiles)**:
  - Each `BeatCheckoutTier` SHALL expose a deterministic `LicenseRightsProfile` specifying:
    - Human title, short entitlement summary, and expandable legal agreement prose interpolated with beat title, BPM, musical key, producer handle, buyer handle, Coin/ZAR consideration, and issue date.
    - Explicit rights ceilings:
      - `basicMp3`: non-exclusive, `100,000` monetized streams, `2,500` commercial downloads, `1` music video, untagged master audio file, `includesStems = false`, `grantsExclusivity = false`.
      - `premiumWav`: non-exclusive, `500,000` monetized streams, `10,000` commercial downloads, `2` music videos + radio broadcast sync, lossless `44.1 kHz` PCM WAV master, `includesStems = false`, `grantsExclusivity = false`.
      - `exclusiveStem`: exclusive buyout, unlimited (`null` cap) streams, unlimited commercial downloads, unlimited worldwide broadcast/TV/film sync, lossless `44.1 kHz` PCM WAV master **plus** all 4 isolated `44.1 kHz` stems (`drums`, `bass`, `melody`, `other`), `includesStems = true`, `grantsExclusivity = true`.
- **`REQ-P58-LIC-04` (Backward-Compatible Wire & Legacy Tier Mapping)**:
  - `BeatCheckoutTier.fromWire(String raw)` MUST accept `'basic_lease'`, `'basic_mp3'`, `'personal'` $\to$ `basicMp3`; `'stems_trackout'`, `'premium_wav'`, `'sync'` $\to$ `premiumWav`; and `'exclusive_stem'`, `'unlimited_commercial'`, `'exclusive'`, `'exclusiveownership'` $\to$ `exclusiveStem`.
  - Mapping to `ProducerBeatEntity` `BeatLicenseTier` SHALL preserve legacy JSON serialization of `ProducerBeatEntity` and `BeatSaleRecord`.
- **`REQ-P58-LIC-05` (Tier Availability & Sold-Exclusive Guard)**:
  - `BeatListingEntity` SHALL carry `availableTiers` (defaulting to all three tiers) and `isExclusiveSold` (`false` by default) + `exclusiveBuyerId` (`null` by default).
  - WHILE `beat.isExclusiveSold == true`, `LicenseAgreementEngine` and `BeatCheckoutNotifier` SHALL reject any new licensing attempt unless explicitly overridden in single-buyer replay checks.

---

## 3. Cryptographic Ownership Certificates & Verification (`REQ-P58-CERT`)

- **`REQ-P58-CERT-01` (Canonical Payload & FIPS 180-4 SHA-256 Digest)**:
  - Upon payment authorization, `SovereignCertificateSigner.issueCertificate(...)` SHALL construct the deterministic UTF-8 pipe-delimited canonical preimage:
    `VHUNAMBI_LIC_V2|<certificateId>|<beatId>|<producerId>|<buyerId>|<tierWireSlug>|<amountCoins>|<amountZar2dp>|<issuedAtUtcIso>|<masterFileSha256>`
  - The signer MUST hash the UTF-8 byte array with `VaultEnvelopeCrypto.sha256Bytes` to produce a lowercase 64-character hexadecimal `licenseHash`. No external `pubspec.yaml` cryptography package SHALL be added.
- **`REQ-P58-CERT-02` (Deterministic Offline Integrity Verification)**:
  - `SovereignCertificateSigner.verifyIntegrity(SovereignLicenseCertificate cert)` SHALL recompute the SHA-256 digest from the certificate's immutable fields and return `true` if and only if the recomputed 64-character hex string equals `cert.licenseHash` AND `cert.licenseHash.length == 64`.
  - Any 1-character alteration to buyer ID, beat ID, tier, Coins paid, ZAR paid, issue timestamp, or master file SHA-256 MUST cause `verifyIntegrity(...)` to return `false`.
- **`REQ-P58-CERT-03` (Hive Certificate Persistence & Headless Safety)**:
  - `LicenseCertificateRepository` SHALL persist `SovereignLicenseCertificate` JSON records in Hive box `AppConstants.licenseCertificatesBoxKey` (`'vhunambi_license_certificates'`).
  - Whenever running in `FLUTTER_TEST` or when Hive is uninitialized, the repository MUST seamlessly fall back to an in-memory map keyed by `certificateId` (and secondary index by `beatId` / `vaultTrackId`) with zero unhandled exceptions.
- **`REQ-P58-CERT-04` (Interactive Certificate Deed Sheet & Export)**:
  - Invoking `"Commercial License"` from `TrackActionsSheet`, `"License Certificate"` on `_LicensedBeatCard` in `BeatsVaultView`, or `"View Certificate"` post-checkout MUST open `LicenseCertificateSheet` displaying:
    - Certificate ID (`CERT-VHB-...`), Beat title/producer/BPM/key, Buyer handle, Tier badge, Coins + ZAR paid, Producer 85% royalty split, Canonical SHA-256 hex pill (`Key('license_cert_hash_pill')`), and Master Asset SHA-256 fingerprint.
    - Live **"Verify Cryptographic Proof"** button (`Key('license_cert_verify_btn')`) displaying live `VERIFIED` (`AppColors.success`) or `TAMPERED / UNVERIFIED` (`AppColors.error`) status.
    - One-tap **"Copy SHA-256"** button (`Key('license_cert_copy_hash_btn')`).
    - Real **"Export / Share Legal Deed"** action (`Key('license_cert_share_btn')`) replacing the legacy `"PDF export ... ships with the licensing release"` stub SnackBar! Clicking export MUST write both `.vhlic.json` and human-readable `.txt` certificate deed files into the Vault export directory and invoke `share_plus` (`Share.shareXFiles`) with graceful headless test fallback showing confirmation SnackBar with saved filename.

---

## 4. Unified Wallet Coin Checkout, Reconciliation & Exclusive Buyout (`REQ-P58-CHK`)

- **`REQ-P58-CHK-01` (Unified Top-Bar Wallet Coins Display)**:
  - `MarketplaceTopBar` SHALL replace its isolated `_CreditChip` (`marketplaceCreditsProvider`) with the shared `VhunambiUserCoinsChip` bound to `creatorWalletProvider.userCoinsBalance`, opening `SubscriptionUpgradeModal.show(context)` on tap while retaining invisible compatibility labels as implemented in `VhunambiUserCoinsChip`.
- **`REQ-P58-CHK-02` (Pre-Checkout Affordability & Inline Coin Top-Up)**:
  - `BeatLicenseModal` SHALL compare `creatorWalletProvider.userCoinsBalance` against `selectedTierPricing.coins` in real time.
  - IF buyer Coins `< tierCoins`, `BeatLicenseModal` MUST display the exact Coin & ZAR deficit, disable the purchase submit action, and surface a prominent **"Top Up Coins"** CTA button (`Key('checkout_topup_btn')`) that opens `SubscriptionUpgradeModal.show(context)`.
  - WHEN the user purchases a top-up pack (`coin_topup_pack_100` / `300` / `1000`), `BeatLicenseModal` MUST reactively recalculate affordability without requiring the user to close and reopen the modal.
- **`REQ-P58-CHK-03` (Atomic Wallet Debit, Conservation Split & Rollback)**:
  - During checkout confirmation:
    1. `CreatorWalletNotifier.debitForBeatPurchase(...)` SHALL atomically verify `userCoinsBalance >= tierCoins` and debit `tierCoins` from `userCoinsBalance`, keeping `marketplaceCreditsProvider` synchronized (`userCoinsBalance ~/ 5`) for legacy callers.
    2. Royalty split MUST follow $C_{\text{prod}} = (C_{\text{gross}} \times 85 + 50) \div 100$ and $C_{\text{plat}} = C_{\text{gross}} - C_{\text{prod}}$.
    3. Producer earnings (`creatorEarnedZar`, `creatorReceivedCoins`) on the local user's wallet SHALL be credited when licensing a beat owned by the current creator or when triggered via legacy compatibility `licenseBeat(ref, beat)` callers, and producer `BeatsNotifier.recordSale(...)` MUST always record the buyer handle, `BeatLicenseTier`, and `creditsEarned`.
    4. IF local asset unpacking fails with an unrecoverable exception, `BeatCheckoutNotifier` MUST atomically refund `tierCoins` back to `creatorWalletProvider.userCoinsBalance`, skip Vault injection, skip Exclusive Lock, and transition state cleanly to rolled-back error state.
- **`REQ-P58-CHK-04` (Exclusive Stem License Buyout Lock)**:
  - WHEN a purchase completes for `BeatCheckoutTier.exclusiveStem`:
    - `MarketplaceBeatsNotifier.markSoldExclusive(beatId: beat.id, buyerId: buyerId)` SHALL immediately set `isExclusiveSold = true` and `exclusiveBuyerId = buyerId`.
    - `filterBeats(...)` MUST exclude sold-exclusive beats from active purchasable marketplace search/grid listings (or lock/filter unless explicitly viewing archived purchases), preventing any second buyer from acquiring overlapping exclusive rights.
    - On the producer's `ProducerBeatEntity`, `BeatsNotifier.recordSale(...)` SHALL set `isExclusiveSold = true` and `exclusiveBuyerId = buyerId`.
- **`REQ-P58-CHK-05` (Offline-First Critical Outbox Sync)**:
  - Every confirmed purchase MUST enqueue a `SyncMutationRecord` via `SyncOutboxService.enqueue(...)` with `priority: SyncPriority.critical`, `entityType: 'beat_license'`, `action: 'purchase'`, and idempotency key `'lic_<certificateId>'`, while attempting live submission to `IMarketplaceRepository.licenseBeat(...)` and surfacing server HTTP `409 Conflict` if an exclusive buyout race occurs online.

---

## 5. Automated 44.1 kHz Un-Tagged Master & Stem Delivery (`REQ-P58-DEL`)

- **`REQ-P58-DEL-01` (Deterministic Post-Checkout Directory Layout)**:
  - `BeatDeliveryUnpackerService` SHALL resolve the vault base path via `IOfflineStorageService.resolveVaultAudioDirectory()` and write unlocked assets under `<vaultAudioDir>/licensed/<beatId>/`:
    - `basicMp3`: `untagged_master.wav` (and record `formatEntitlement = 'mp3_standard'`).
    - `premiumWav`: `master_44k1.wav` (lossless `44.1 kHz` 16-bit Stereo PCM WAV).
    - `exclusiveStem`: `master_44k1.wav` PLUS `drums_44k1.wav`, `bass_44k1.wav`, `melody_44k1.wav`, `other_44k1.wav` (all `44.1 kHz` 16-bit Stereo PCM WAV).
- **`REQ-P58-DEL-02` (Hybrid Network Download + Offline Deterministic 44.1 kHz Synthesis)**:
  - WHEN valid remote HTTP/HTTPS URLs are reachable and network mode is online (and not in headless `FLUTTER_TEST` mode), `BeatDeliveryUnpackerService` SHOULD attempt `Dio` streaming download of master/stem payloads first, validating non-empty bytes.
  - WHEN running offline, in `FLUTTER_TEST`, or when demo CDN URLs (`cdn.vhunambi.com` / `r2.vhunambi.com`) are unreachable, `BeatDeliveryUnpackerService` MUST automatically invoke `MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(...)` with a genre-, key-, and BPM-matched `MultiTrackGrooveEntity` seeded from `beat.id` to produce authentic un-tagged `44.1 kHz` 16-bit Stereo PCM RIFF/WAVE files (plus solo-channel stem renders for `drums`, `bass`, `melody` [chords+lead], `other` [hats/perc]) and write them via `WavFileWriter` (`writeWavToFile`).
- **`REQ-P58-DEL-03` (RIFF/WAV Header & Non-Empty Byte Verification)**:
  - Every unpacked audio file MUST be verified to begin with valid RIFF/`WAVE` bytes (when generated locally) or non-zero payload length, have `File.existsSync() == true`, and contribute its SHA-256 digest (`VaultEnvelopeCrypto.sha256Bytes`) to `UnpackedBeatPackage.masterFileSha256` prior to `SovereignLicenseCertificate` finalization (or bound immediately into certificate metadata).
- **`REQ-P58-DEL-04` (Automatic Library Vault & Offline Cache Injection)**:
  - `BeatCheckoutNotifier` SHALL insert or update a `LibraryTrack` in `libraryTracksProvider` with:
    - `id: 'market_${beat.id}'`
    - `localAudioFilePath: package.masterPath`
    - `masterAudioFilePath: package.masterPath`
    - `stemPaths: package.stemPaths` (4-entry map for `exclusiveStem`, empty map for non-stem tiers)
    - `licenseType: tier.displayName`
    - `licenseTierId: tier.wireSlug`
    - `licenseCertificateIdOverride: certificate.certificateId`
    - `licenseHash: certificate.licenseHash`
    - `syncStatus: TrackSyncStatus.cachedLocally`
    - `isInstrumental: beat.assetCategory == MarketplaceAssetCategory.beats || beat.assetCategory == MarketplaceAssetCategory.liveInstruments`
  - AND register the file in `OfflineStorageService.saveTrackMetadata(...)` so storage quota and offline playback work immediately via `just_audio` with zero internet connection.
- **`REQ-P58-DEL-05` (Vault Stems Drawer & Studio Integration)**:
  - In `BeatsVaultView`'s Licensed Beats tab (`_LicensedBeatCard`), tracks with `track.stemPaths.isNotEmpty` SHALL render a **"Stems (4)"** / **Play Stem** expandable drawer button (`Key('licensed_beat_stems_btn_${track.id}')`) enabling individual stem preview playback (`drums`, `bass`, `melody`, `other`), individual `.wav` file sharing via `share_plus`, and 1-tap **"Use in Studio"** loading into `ReferenceAudioDropzone` & `MelodySketchpad` + `StemMixer`.
  - `ReferenceAudioDropzone._showBeatPicker` SHALL list licensed Vault instrumentals alongside user-produced beats using `localAudioFilePath ?? remoteAudioUrl`.

---

## 6. Backend API & SQLite WAL Atomicity (`REQ-P58-API`)

- **`REQ-P58-API-01` (SQLite Persistent Schema Additions)**:
  - `VhunambiDatabase` (`apps/vhunambi_api/src/db/vhunambi_db.ts`) SHALL create/migrate:
    - `marketplace_assets` with columns supporting `is_exclusive_sold INTEGER DEFAULT 0` and `exclusive_buyer_id TEXT`.
    - `beat_licenses` table storing `(certificate_id TEXT PRIMARY KEY, license_hash TEXT UNIQUE NOT NULL, beat_id TEXT NOT NULL, producer_id TEXT NOT NULL, buyer_id TEXT NOT NULL, tier TEXT NOT NULL, coins_paid INTEGER NOT NULL, zar_paid REAL NOT NULL, producer_coins INTEGER NOT NULL, producer_zar REAL NOT NULL, issued_at TEXT NOT NULL, data_json TEXT NOT NULL)`.
- **`REQ-P58-API-02` (ACID Exclusive Lock & Royalty Settlement)**:
  - `POST /api/marketplace/beats/:id/license` SHALL execute inside an immediate SQLite transaction (`BEGIN IMMEDIATE ... COMMIT` / `ROLLBACK`):
    - Reject nonexistent beat with HTTP `404`.
    - Reject already exclusively sold beat (`is_exclusive_sold === 1`) with HTTP `409 Conflict` (`{ error: 'Beat has already been sold exclusively' }`).
    - When `enforceBalance` / wallet record exists and buyer Coins `< tierCoins`, return HTTP `402 Payment Required`.
    - Record buyer Coin debit entry (`type: 'license_purchase'`) and producer 85% credit entry (`type: 'license_sale'`) in `wallet_ledger`.
    - Persist row in `beat_licenses` with identical canonical `VHUNAMBI_LIC_V2|...` SHA-256 hash.
    - When `tier` is `'exclusive_stem'` or `'unlimited_commercial'`, update `marketplace_assets.is_exclusive_sold = 1` and `exclusive_buyer_id = buyerId`.
- **`REQ-P58-API-03` (Certificate Retrieval & Integrity Endpoint)**:
  - `GET /api/marketplace/licenses/:buyerId` SHALL query persisted `beat_licenses` rows for `:buyerId` in addition to any seeded items.
  - `GET /api/marketplace/licenses/verify/:certificateId` SHALL return `{ valid: boolean, certificateId, licenseHash, beatId, buyerId, tier, issuedAt }` by recomputing the canonical SHA-256 digest on the server.
- **`REQ-P58-API-04` (Sync Mutation Handler Support)**:
  - `VhunambiDatabase.applyMutationsBatch` SHALL handle `entityType === 'beat_license' && action === 'purchase'` idempotently via `idempotencyKey`.

---

## 7. Non-Functional Requirements, UI Ergonomics & Traceability (`REQ-P58-NFR`)

- **`REQ-P58-NFR-01` (Zero Emoji & Design Token Compliance — `STD-UIUX-001`)**:
  - All new and modified Flutter widgets MUST use `AppIcons.*` / verified `phosphor_icons`, `AppColors.*` (`surfaceCanvasOf`, `surfaceElevatedOf`, `brandPrimary`, `coinGold`, `badgeCyan`, `success`, `error`), `AppTypography.*`, `AppSpacing.*`, and `AppRadius.*`. Zero hardcoded hex literals and zero raw Unicode emojis in Dart widget trees.
- **`REQ-P58-NFR-02` (Deterministic Semantic Widget Keys)**:
  - Every interactive element MUST define semantic widget `Key('...')` identifiers listed in §7.3 so widget tests are 100% deterministic.
- **`REQ-P58-NFR-03` (Headless Test Isolation & Zero Regressions)**:
  - All domain, crypto, repository, unpacker, and checkout notifier classes MUST execute cleanly inside `flutter test` (`Directory.systemTemp` file IO, in-memory Hive fallback) and maintain 100% pass rate across prior Phase 28, Phase 39, Phase 40, and backend tests.

### 7.3 Master Requirement-to-Test Traceability Matrix

| Req ID | Owning Component / File | Primary Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P58-LIC-01..05` | `LicenseAgreementEngine`, `BeatCheckoutTier` | `phase58_licensing_domain_test.dart`: tier multipliers `1x/3x/6x`, stream limits, legacy wire mapping, exclusive sold rejection |
| `REQ-P58-CERT-01..02` | `SovereignCertificateSigner` (`VaultEnvelopeCrypto.sha256Bytes`) | `phase58_licensing_domain_test.dart`: deterministic 64-char hex digest & 1-char tamper detection |
| `REQ-P58-CERT-03..04` | `LicenseCertificateRepository`, `LicenseCertificateSheet`, `CertificateShareExporter` | `phase58_checkout_widget_test.dart`: Hive fallback storage, sheet verify pill, hash copy & deed file export |
| `REQ-P58-CHK-01..05` | `MarketplaceTopBar`, `BeatLicenseModal`, `BeatCheckoutNotifier`, `CreatorWalletNotifier` | `phase58_checkout_widget_test.dart` & `phase58_checkout_orchestrator_test.dart`: Coin debit, deficit Top-Up CTA, 85/15 split conservation, rollback refund, Exclusive Lock, critical outbox record |
| `REQ-P58-DEL-01..05` | `BeatDeliveryUnpackerService`, `LibraryTrack`, `BeatsVaultView`, `ReferenceAudioDropzone` | `phase58_delivery_unpacker_test.dart` & `phase58_checkout_widget_test.dart`: 44.1 kHz WAV RIFF headers on disk for master + 4 stems, Vault injection & Studio Stem Drawer |
| `REQ-P58-API-01..04` | `VhunambiDatabase`, `marketplace_service.ts`, `marketplace_routes.ts` | `marketplace_phase58.test.ts` (API test): ACID debit/credit split, `beat_licenses` row, SHA-256 verification endpoint, HTTP `409` duplicate exclusive rejection |
