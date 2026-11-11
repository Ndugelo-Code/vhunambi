# Phase 61: Sovereign Identity, Authentication & Multi-Tenant Security Convergence — System Requirements

> **Document ID:** `VHUNAMBI-SPEC-P61-REQUIREMENTS-V1`
> **Phase:** `61 — Sovereign Identity, Authentication & Multi-Tenant Security Convergence`
> **Engineering Standard:** `All-Gemini Engineering Standard (EARS + RFC-2119 Formal Specification)`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR EXECUTION`

---

## 1. Scope & EARS / RFC-2119 Conventions

This specification defines the formal functional, security, cryptographic, and non-functional requirements for **Phase 61: Sovereign Identity, Authentication & Multi-Tenant Security Convergence** across `apps/vhunambi_api` (Node.js + Hono + `node:sqlite`) and `apps/vhunambi_client` (Flutter + Riverpod + Hive).

All requirements follow the **Easy Approach to Requirements Syntax (EARS)** (`UBIQUITOUS`, `EVENT-DRIVEN`, `STATE-DRIVEN`, `UNWANTED-BEHAVIOR`) paired with **RFC-2119** normative keywords (`MUST`, `MUST NOT`, `SHALL`, `SHOULD`, `MAY`). Every requirement is mapped to concrete implementation files and automated verification tests in Section 8.

---

## 2. Backend Identity & SQLite Schema Requirements (`REQ-P61-DB`)

### `REQ-P61-DB-01`: `users` & `auth_sessions` Schema & Migration Safety
- **Pattern:** `UBIQUITOUS`
- **Statement:** The `VhunambiDatabase` engine (`apps/vhunambi_api/src/db/vhunambi_db.ts`) **MUST** create and maintain two new SQLite tables—`users` and `auth_sessions`—alongside an idempotent schema migration that adds `creator_id TEXT NOT NULL DEFAULT 'system'` (plus composite index `idx_sync_mutation_creator_seq`) to `sync_mutation_log` without dropping or corrupting existing data.
- **Acceptance Criteria:**
  1. `users` table stores `user_id TEXT PRIMARY KEY`, `creator_id TEXT NOT NULL UNIQUE`, `handle TEXT NOT NULL UNIQUE`, `email TEXT NOT NULL UNIQUE`, `password_hash TEXT NOT NULL`, `role TEXT NOT NULL DEFAULT 'creator'`, `created_at TEXT NOT NULL`, and `updated_at TEXT NOT NULL`.
  2. `auth_sessions` table stores `session_id TEXT PRIMARY KEY`, `user_id TEXT NOT NULL`, `creator_id TEXT NOT NULL`, `family_id TEXT NOT NULL`, `refresh_token_hash TEXT NOT NULL`, `previous_token_hash TEXT`, `device_label TEXT NOT NULL DEFAULT 'vhunambi_client'`, `expires_at TEXT NOT NULL`, `revoked INTEGER NOT NULL DEFAULT 0`, `revoke_reason TEXT`, `created_at TEXT NOT NULL`, and `rotated_at TEXT NOT NULL`.
  3. Existing databases created prior to Phase 61 automatically gain the `creator_id` column on `sync_mutation_log` via `PRAGMA table_info(sync_mutation_log)` inspection during `migrate()`.

### `REQ-P61-DB-02`: Seeded Sovereign Creator Credentials
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `VhunambiDatabase.seedIfEmpty()` runs on bootstrap, the database **MUST** seed deterministic sovereign user accounts in `users` corresponding to the seeded creators (`creator_cern` / `@cern`, `creator_makhadzi` / `@makhadzi`, `creator_kabza` / `@kabza`, `creator_focalistic` / `@focalistic`, `creator_tyla` / `@tyla`, `creator_black_coffee` / `@blackcoffee`) with memory-hard `scrypt` password hashes so developers and automated test suites can authenticate immediately.
- **Acceptance Criteria:**
  1. Each seeded creator has a matching `users` record linking `creator_id` (e.g., `'creator_cern'`), normalized `handle` (e.g., `'@cern'`), email (e.g., `'cern@vhunambi.co.za'`), and a valid `scrypt` password hash for the default sovereign test/demo credential (`'VhunambiSovereign!2026'`).
  2. Registering a new user via `registerUser()` atomically creates both the `creators` row (with initial welcome wallet credit of `2500` coins / `R 250.00` if not yet present) and the `users` row inside a `BEGIN IMMEDIATE` transaction.

### `REQ-P61-DB-03`: Memory-Hard `scrypt` Password Hashing & Constant-Time Verification
- **Pattern:** `UBIQUITOUS`
- **Statement:** The backend cryptographic helper (`apps/vhunambi_api/src/security/crypto_token.ts`) **MUST** hash all passwords using `node:crypto.scryptSync` with parameters $N = 16384, r = 8, p = 1, \text{keylen} = 64$ and a 16-byte CSPRNG salt, and **MUST** verify passwords using `node:crypto.timingSafeEqual`.
- **Acceptance Criteria:**
  1. Plaintext passwords are never logged or written to SQLite.
  2. `verifyPassword(password, storedHash)` returns `true` for the exact password and `false` for any mutated password or malformed hash string without throwing unhandled exceptions.

---

## 3. Backend Auth Endpoints, JWT & Tenant Middleware Requirements (`REQ-P61-AUTH`)

### `REQ-P61-AUTH-01`: Authentication Lifecycle REST API (`/api/auth/*`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client requests `/api/auth/register`, `/api/auth/login`, `/api/auth/refresh`, `/api/auth/logout`, `/api/auth/me`, or `/api/auth/sessions` (or their `/v1/auth/*` and `/api/v1/auth/*` aliases), the backend **MUST** execute the corresponding identity operation and return structured JSON responses.
- **Acceptance Criteria:**
  1. `POST /api/auth/register` validates `handle`, `email`, `password` (minimum 8 chars), and `displayName`; rejects duplicate handles/emails with `409 CONFLICT` (`AUTH_IDENTITY_EXISTS`); and returns `201 Created` with `{ user, session, accessToken, refreshToken, expiresAt }`.
  2. `POST /api/auth/login` accepts `{ identifier, password }` (matching either `email` or `handle` with or without leading `'@'`) and returns `200 OK` with `{ user, session, accessToken, refreshToken, expiresAt }`, or `401 UNAUTHORIZED` (`INVALID_CREDENTIALS`) on mismatch.
  3. `POST /api/auth/refresh` accepts `{ refreshToken }`, rotates the session's `refresh_token_hash` (storing the old hash in `previous_token_hash`), and returns a fresh `{ accessToken, refreshToken, expiresAt }`.
  4. `POST /api/auth/logout` revokes the active session (`revoked = 1`, `revoke_reason = 'USER_LOGOUT'`) and returns `200 OK`.
  5. `GET /api/auth/me` and `GET /api/auth/sessions` require a valid Bearer token (`401` if missing or invalid) and return the authenticated user's profile, wallet summary, and active session list.

### `REQ-P61-AUTH-02`: Refresh Token Reuse Detection & Family Revocation
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** a caller presents an already-rotated `refreshToken` matching `previous_token_hash` on `POST /api/auth/refresh`, **THEN** the backend **MUST** immediately revoke all sessions belonging to that `family_id` (`revoked = 1`, `revoke_reason = 'TOKEN_REUSE_DETECTED'`) and return `401 UNAUTHORIZED` (`AUTH_TOKEN_REUSE_DETECTED`).
- **Acceptance Criteria:**
  1. Replaying a rotated refresh token invalidates the entire session family so neither the replayed token nor the newly rotated token can refresh again.

### `REQ-P61-AUTH-03`: Dual-Gate Tenant Middleware & Legacy Test Compatibility (`sovereignAuthMiddleware`)
- **Pattern:** `STATE-DRIVEN`
- **Statement:** **WHILE** handling requests to domain routes (`/api/wallet/*`, `/api/library/*`, `/api/playlists/*`, `/api/marketplace/*`, `/api/sync/*`, `/api/creators/:id/wallet/*`), `sovereignAuthMiddleware` **MUST** enforce strict cryptographic JWT validation and tenant ownership whenever an `Authorization` header is supplied or strict auth mode is requested (`x-vhunambi-enforce-auth: true` or `VHUNAMBI_AUTH_MODE=strict`), while preserving fallback compatibility for unauthenticated legacy test suite calls.
- **Acceptance Criteria:**
  1. If `Authorization: Bearer <token>` is present and the token is malformed, tampered, expired, or its session is revoked in `auth_sessions`, the middleware **MUST** return `401 UNAUTHORIZED` (`AUTH_TOKEN_INVALID` or `AUTH_SESSION_REVOKED`).
  2. If `Authorization` is missing and either `x-vhunambi-enforce-auth: true` header or `VHUNAMBI_AUTH_MODE=strict` is set, the middleware **MUST** return `401 UNAUTHORIZED` (`AUTH_REQUIRED`).
  3. If `Authorization: Bearer <token>` is valid, `c.get('authUser')` is populated with `{ userId, creatorId, handle, role, sessionId }`, and any attempt to access or mutate another creator's private resource **MUST** return `403 FORBIDDEN` (`TENANT_FORBIDDEN`).

---

## 4. Backend Financial Atomicity & IDOR/Exploit Closure Requirements (`REQ-P61-SEC`)

### `REQ-P61-SEC-01`: Wallet IDOR Prevention & Atomic `BEGIN IMMEDIATE` Payout Lock
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** an authenticated caller requests `GET /api/wallet/:creatorId`, `POST /api/wallet/payout`, `GET /api/creators/:id/wallet`, or `POST /api/creators/:id/wallet/withdraw` for a `creatorId` that does not match `authUser.creatorId`, **THEN** the route **MUST** reject the request with `403 FORBIDDEN` (`TENANT_FORBIDDEN`). Furthermore, `VhunambiDatabase.requestPayout()` **MUST** execute balance verification, bank account persistence, ledger debit insertion, and sync mutation logging inside a single `BEGIN IMMEDIATE ... COMMIT` transaction block.
- **Acceptance Criteria:**
  1. Cross-tenant wallet reads and payouts return `403 FORBIDDEN`.
  2. `requestPayout()` uses `BEGIN IMMEDIATE` and `COMMIT`/`ROLLBACK` so concurrent or sequential over-withdrawals deterministically throw `INSUFFICIENT_FUNDS` (`422`) without ever driving `balanceCoins` negative.

### `REQ-P61-SEC-02`: Elimination of Free Beat License & Exclusive Buyout Exploit (`F-03`)
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** a beat license purchase (`POST /api/marketplace/beats/:id/license` or `POST /api/marketplace/license`) is invoked by an authenticated user (`authUser` present) or with `x-vhunambi-enforce-auth: true` or `enforceWalletBalance: true`, **THEN** the backend **MUST**:
  1. Reject any `buyerId` that does not match `authUser.creatorId` (`403 TENANT_FORBIDDEN`),
  2. Force `enforceBuyerWallet = true` regardless of whether `hasWalletActivity(buyerId)` is `false`, and
  3. Reject any buyer whose coin balance is less than `priceCoins` with `402 Payment Required` (`INSUFFICIENT_WALLET_BALANCE`) before minting any license, crediting seller royalties, or locking exclusive rights.
- **Acceptance Criteria:**
  1. An authenticated buyer with `0` coins and zero prior wallet history attempting to buy a beat or `EXCLUSIVE_RIGHTS` license receives `402 INSUFFICIENT_WALLET_BALANCE`; the beat remains available (`sold_exclusive = 0`) and the seller receives `0` unearned royalties.
  2. Authenticated `GET /api/marketplace/licenses/:buyerId` returns `403 TENANT_FORBIDDEN` if `:buyerId !== authUser.creatorId`.

### `REQ-P61-SEC-03`: Library & Playlist Row Ownership Enforcement (`F-05`)
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** an authenticated user attempts to read, create, update, or delete a Library item (`/api/library/*`) or Playlist (`/api/playlists/*`) belonging to a different `creatorId`, **THEN** the backend **MUST** return `403 FORBIDDEN` (`TENANT_FORBIDDEN`), and `deleteLibraryItem(trackId, creatorId)` **MUST** scope its `DELETE` statement by `creator_id` whenever `creatorId` is provided.
- **Acceptance Criteria:**
  1. User A cannot overwrite or delete User B's playlist via `POST /api/playlists`, `PUT /api/playlists/:id`, or `DELETE /api/playlists/:id` (`403 FORBIDDEN`).
  2. User A calling `DELETE /api/library/:trackId` only deletes User A's library entry and never deletes User B's saved entry for the same track.

### `REQ-P61-SEC-04`: Tenant-Scoped Delta-Sync Stream & Batch Mutation Isolation (`F-04`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client calls `GET /api/sync/delta` or `POST /api/sync/mutations`, the backend **MUST** scope private entity mutations (`payout`, `library_track`, `beat_license`, and non-public `playlist`) to the caller's `creatorId` and reject cross-tenant batch mutations with `403 FORBIDDEN` (`TENANT_FORBIDDEN`).
- **Acceptance Criteria:**
  1. `recordMutation(entityType, entityId, op, payload, creatorId)` stores the owning `creator_id` in `sync_mutation_log`.
  2. When an authenticated user (or a request specifying `?creatorId=...`) calls `GET /api/sync/delta`, private mutations belonging to other creators (especially `payout` bank receipts and private `library_track` mutations) are excluded from the returned `mutations` array.

---

## 5. Client Session Vault, API Client, Identity Unification & Hive Sanitizer Requirements (`REQ-P61-CLI`)

### `REQ-P61-CLI-01`: Per-Device CSPRNG Entropy in `HiveAesVaultCipher` (`F-07`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `HiveService.init()` initializes local storage, `HiveAesVaultCipher.ensureDeviceGenesisSalt()` **MUST** generate a 32-byte cryptographically random salt via `Random.secure()` on first boot, persist it in `vhunambi_prefs` under `'sovereign_device_genesis_salt_v61'`, and derive the 256-bit Tier-0 Hive AES key using HKDF-SHA256 over that device-unique salt.
- **Acceptance Criteria:**
  1. Two independent device installations generate distinct 32-byte genesis salts and distinct 256-bit AES keys.
  2. Re-initializing `HiveAesVaultCipher` on the same device reuses the persisted `'sovereign_device_genesis_salt_v61'` so encrypted Tier-0 boxes (`vhunambi_tokens`, `vhunambi_wallet_ledger_box`, `vhunambi_license_certificates`, `vhunambi_creator_dna`) unlock deterministically across app restarts.

### `REQ-P61-CLI-02`: Tier-0 `vhunambi_tokens` Session Persistence (`SovereignAuthRepository`)
- **Pattern:** `UBIQUITOUS`
- **Statement:** The client `SovereignAuthRepository` (`lib/core/auth/sovereign_auth_repository.dart`) **MUST** persist and restore `SovereignAuthSession` inside the Tier-0 AES-256 encrypted Hive box `vhunambi_tokens` (`AppConstants.tokenBoxKey`) under key `'sovereign_auth_session_v1'`.
- **Acceptance Criteria:**
  1. `SovereignAuthSession` serializes `userId`, `creatorId`, `handle`, `displayName`, `email`, `accessToken`, `refreshToken`, `expiresAtIso`, `sessionId`, and `authMode` (`SovereignAuthMode.authenticated` or `SovereignAuthMode.guestSeeded`).
  2. Cold-starting the client restores the persisted authenticated session from `vhunambi_tokens` without requiring the user to re-enter credentials.

### `REQ-P61-CLI-03`: 6-Way Client Identity Unification (`currentCreatorIdProvider`)
- **Pattern:** `UBIQUITOUS`
- **Statement:** All client repositories and Riverpod notifiers across Library, Playlists, Wallet, Marketplace Licensing, Social Feed/Reels Comments, and Content Studio/Owner Profile **MUST** resolve the active user's identity from `currentCreatorIdProvider` and `currentCreatorHandleProvider` (`lib/core/auth/auth_providers.dart`), with `canonicalizeCreatorId()` normalizing legacy aliases (`'me'`, `'usr_me'`, `'buyer_user'`, `'buyer_default'`, `'vhunambi_user'`) to the active canonical creator ID (`'creator_cern'` default).
- **Acceptance Criteria:**
  1. Signing in as `@makhadzi` (`'creator_makhadzi'`) or `@cern` (`'creator_cern'`) immediately updates `currentCreatorIdProvider` and `currentCreatorHandleProvider` across Library, Playlists, Wallet, Marketplace Checkout, Social Posts, Reels Comments, and Profile.

### `REQ-P61-CLI-04`: `SovereignApiClient` Bearer Injection & Single-Flight `401` Refresh
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** any HTTP repository makes an API request through `SovereignApiClient` (`lib/core/network/sovereign_api_client.dart`), the client **MUST** attach `Authorization: Bearer <accessToken>` (when authenticated) and `X-Vhunambi-Creator-Id: <creatorId>`, resolve the base URL via `AppConstants.resolveApiRootUrl()`, and automatically perform a single-flight `POST /api/auth/refresh` token rotation if a protected request returns `401`.
- **Acceptance Criteria:**
  1. Concurrent requests encountering `401` await a single shared refresh future rather than triggering duplicate refresh calls.
  2. If refresh succeeds, `vhunambi_tokens` is updated and the original request is replayed transparently; if refresh fails with `401`, the session transitions cleanly and notifies `NetworkErrorHandler`.

### `REQ-P61-CLI-05`: Multi-User Hive Partition Sanitizer (`SovereignHiveAccountSanitizer`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a user signs out or switches from `previousCreatorId` to a different `nextCreatorId`, `SovereignHiveAccountSanitizer` **MUST** purge tenant-private Hive data (`vhunambi_wallet_ledger_box`, `vhunambi_library_tracks_v1`, `vhunambi_playlists`, `vhunambi_sync_outbox_box`, `vhunambi_license_certificates`, `vhunambi_creator_dna`, `vhunambi_profiles['profile_me']`, and `vhunambi_prefs['edge_sync_last_seq']`) while preserving public catalog boxes (`vhunambi_tracks`, `vhunambi_marketplace_catalog_box`, `vhunambi_sound_packs_box`) and the device genesis salt.
- **Acceptance Criteria:**
  1. After signing out of User A or switching to User B, zero wallet ledger entries, private playlists, library tracks, or license certificates from User A remain in Hive.
  2. Public Explore tracks (`vhunambi_tracks`) and Marketplace beat listings (`vhunambi_marketplace_catalog_box`) remain intact.

---

## 6. Auth Sheet & Settings Identity HUD Requirements (`REQ-P61-HUD`)

### `REQ-P61-HUD-01`: `AccountIdentitySecurityCard` in `ProfileSettingsDrawer`
- **Pattern:** `UBIQUITOUS`
- **Statement:** `ProfileSettingsDrawer` (`lib/features/profile/presentation/widgets/profile_settings_drawer.dart`) **MUST** render `AccountIdentitySecurityCard` (`Key('auth_identity_security_card')`) displaying the active creator's display name, handle (`Key('auth_creator_handle_text')`), canonical `creatorId`, verification mode pill (`Key('auth_mode_badge_pill')`), AES-256 vault status, and interactive triggers to open `SovereignAuthSheet` (`Key('auth_open_sheet_btn')`), switch accounts (`Key('auth_switch_account_btn')`), or sign out (`Key('auth_sign_out_btn')`).
- **Acceptance Criteria:**
  1. Uses `AppColors`, `AppTypography`, `PhosphorIcons`, and `HYDRATION_SAFE_VARIANTS` with zero raw emojis.
  2. Tapping `Key('auth_open_sheet_btn')` or `Key('auth_switch_account_btn')` opens `SovereignAuthSheet`; tapping `Key('auth_sign_out_btn')` invokes `authSessionProvider.notifier.signOut()`.

### `REQ-P61-HUD-02`: `SovereignAuthSheet` Modal (Login, Register & Demo Presets)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `SovereignAuthSheet` (`Key('sovereign_auth_sheet')`) is presented, it **MUST** provide mode tabs for **Sign In** (`Key('auth_tab_login')`) and **Create Creator Account** (`Key('auth_tab_register')`), form inputs for handle/email (`Key('auth_email_or_handle_input')`), password (`Key('auth_password_input')`), and display name (`Key('auth_display_name_input')`), one-tap developer/creator preset chips (`Key('auth_preset_cern')`, `Key('auth_preset_makhadzi')`), a primary submit button (`Key('auth_submit_primary_btn')`), and a guest fallback action (`Key('auth_continue_guest_btn')`).
- **Acceptance Criteria:**
  1. Submitting valid credentials calls `authSessionProvider.notifier.signIn(...)` or `register(...)`, closes the sheet on success, and updates the HUD card.
  2. Validation or server errors render inline inside `Key('auth_error_banner')` using `AppColors.crimsonAlert`.

---

## 7. Non-Functional Requirements (`REQ-P61-NFR`)

- **`REQ-P61-NFR-01` (Zero External Auth Dependencies):** All backend hashing, HMAC signing, CSPRNG generation, and token rotation **MUST** use Node.js built-in `node:crypto` and `node:sqlite` with zero third-party native addon packages.
- **`REQ-P61-NFR-02` (Zero Analyzer Issues & `STD-UIUX-001` Compliance):** All Dart code **MUST** pass `flutter analyze` with zero errors/warnings and contain zero raw emojis or hardcoded hex colors outside `AppColors`.
- **`REQ-P61-NFR-03` (100% Backward Compatibility with Existing Test Suites):** All 17 existing backend test files and all existing Flutter unit/widget tests **MUST** continue to pass without regressions.

---

## 8. Complete Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation Files | Verification Test Suite | Gate |
| :--- | :--- | :--- | :--- |
| `REQ-P61-DB-01` | `apps/vhunambi_api/src/db/vhunambi_db.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01` |
| `REQ-P61-DB-02` | `apps/vhunambi_api/src/db/vhunambi_db.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01` |
| `REQ-P61-DB-03` | `apps/vhunambi_api/src/security/crypto_token.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01` |
| `REQ-P61-AUTH-01` | `apps/vhunambi_api/src/routes/auth_routes.ts`, `server.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01` |
| `REQ-P61-AUTH-02` | `apps/vhunambi_api/src/db/vhunambi_db.ts`, `auth_routes.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01` |
| `REQ-P61-AUTH-03` | `apps/vhunambi_api/src/middleware/auth_middleware.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-02`, `G-61-05` |
| `REQ-P61-SEC-01` | `apps/vhunambi_api/src/routes/wallet_routes.ts`, `social_routes.ts`, `vhunambi_db.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-02`, `G-61-03` |
| `REQ-P61-SEC-02` | `apps/vhunambi_api/src/services/marketplace_service.ts`, `marketplace_routes.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-03` |
| `REQ-P61-SEC-03` | `apps/vhunambi_api/src/routes/library_routes.ts`, `playlist_routes.ts`, `vhunambi_db.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-02` |
| `REQ-P61-SEC-04` | `apps/vhunambi_api/src/routes/sync_routes.ts`, `vhunambi_db.ts` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-04` |
| `REQ-P61-CLI-01` | `apps/vhunambi_client/lib/core/storage/hive_aes_vault_cipher.dart`, `hive_service.dart` | `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` | `G-61-06` |
| `REQ-P61-CLI-02` | `apps/vhunambi_client/lib/core/auth/sovereign_auth_session.dart`, `sovereign_auth_repository.dart` | `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` | `G-61-06` |
| `REQ-P61-CLI-03` | `apps/vhunambi_client/lib/core/auth/auth_providers.dart`, `creator_id_utils.dart` | `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` | `G-61-06` |
| `REQ-P61-CLI-04` | `apps/vhunambi_client/lib/core/network/sovereign_api_client.dart`, `app_constants.dart` | `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` | `G-61-07` |
| `REQ-P61-CLI-05` | `apps/vhunambi_client/lib/core/auth/sovereign_hive_account_sanitizer.dart` | `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` | `G-61-07` |
| `REQ-P61-HUD-01` | `apps/vhunambi_client/lib/features/profile/presentation/widgets/account_identity_security_card.dart` | `apps/vhunambi_client/test/features/auth/sovereign_auth_hud_widget_test.dart` | `G-61-08` |
| `REQ-P61-HUD-02` | `apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart` | `apps/vhunambi_client/test/features/auth/sovereign_auth_hud_widget_test.dart` | `G-61-08` |

