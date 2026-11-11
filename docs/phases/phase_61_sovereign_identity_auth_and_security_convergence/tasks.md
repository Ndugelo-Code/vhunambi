# Phase 61: Sovereign Identity, Authentication & Multi-Tenant Security Convergence — Execution Tasks & Verification Plan

> **Document ID:** `VHUNAMBI-SPEC-P61-TASKS-V1`
> **Phase:** `61 — Sovereign Identity, Authentication & Multi-Tenant Security Convergence`
> **Engineering Standard:** `All-Gemini Engineering Standard`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR EXECUTION`

---

## 1. Master Milestone Roadmap (`M61.1` – `M61.6`)

| Milestone ID | Milestone Name | Target Package | Verification Gate |
| :--- | :--- | :--- | :--- |
| **`M61.1`** | **Backend Cryptographic Token Engine & SQLite Auth Schema** | `apps/vhunambi_api` | `G-61-01` |
| **`M61.2`** | **Backend `/api/auth/*` Endpoints & Dual-Gate Tenant Middleware** | `apps/vhunambi_api` | `G-61-01`, `G-61-02`, `G-61-05` |
| **`M61.3`** | **Atomic Payout `BEGIN IMMEDIATE` Lock, Zero-Coin Exploit Closure & Tenant Delta-Sync** | `apps/vhunambi_api` | `G-61-02`, `G-61-03`, `G-61-04`, `G-61-05` |
| **`M61.4`** | **Client Per-Device CSPRNG Vault Salt, `vhunambi_tokens` Session & `SovereignApiClient`** | `apps/vhunambi_client` | `G-61-06`, `G-61-07` |
| **`M61.5`** | **6-Way Client Identity Unification & Multi-User Hive Account Sanitizer** | `apps/vhunambi_client` | `G-61-06`, `G-61-07` |
| **`M61.6`** | **Obsidian Identity Security HUD, `SovereignAuthSheet` & Full-Stack Verification Suites** | `apps/vhunambi_api` + `apps/vhunambi_client` | `G-61-01` .. `G-61-08` |

---

## 2. Granular Implementation Tasks (`61.1.1` – `61.6.4`)

### Milestone `M61.1`: Backend Cryptographic Token Engine & SQLite Auth Schema
- [ ] **Task `61.1.1` (`crypto_token.ts`)**: Create `apps/vhunambi_api/src/security/crypto_token.ts` implementing `hashPassword`, `verifyPassword` (`node:crypto.scryptSync` $N=16384, r=8, p=1, L=64$ + `timingSafeEqual`), `signAccessJwt`, `verifyAccessJwt` (`HS256` HMAC-SHA256 + `timingSafeEqual`), `generateRefreshTokenPair`, and `hashRefreshToken` (`SHA-256`).
- [ ] **Task `61.1.2` (`vhunambi_db.ts` Schema & Seed)**: Upgrade `VhunambiDatabase.migrate()` in `apps/vhunambi_api/src/db/vhunambi_db.ts` to create the `users` and `auth_sessions` tables, idempotently add `creator_id` (`idx_sync_mutation_creator_seq`) to `sync_mutation_log`, and implement `seedUsersIfEmpty()` to seed deterministic sovereign accounts (`@cern`, `@makhadzi`, `@kabza`, `@focalistic`, `@tyla`, `@blackcoffee`).
- [ ] **Task `61.1.3` (`vhunambi_db.ts` Auth Operations)**: Implement `registerUser`, `authenticateUser`, `rotateRefreshToken` (with family-wide reuse detection and revocation), `revokeSession`, `isSessionActive`, `getUserByCreatorId`, `listSessionsForCreator`, and `getPlaylistOwnerCreatorId` in `VhunambiDatabase`.

### Milestone `M61.2`: Backend `/api/auth/*` Endpoints & Dual-Gate Tenant Middleware
- [ ] **Task `61.2.1` (`auth_middleware.ts`)**: Create `apps/vhunambi_api/src/middleware/auth_middleware.ts` implementing `sovereignAuthMiddleware`, `requireAuthenticatedUser`, `assertTenantCreatorAccess`, `resolveEffectiveCreatorId`, and `isStrictAuthEnforced`.
- [ ] **Task `61.2.2` (`auth_routes.ts` & `server.ts`)**: Create `apps/vhunambi_api/src/routes/auth_routes.ts` (`POST /register`, `POST /login`, `POST /refresh`, `POST /logout`, `GET /me`, `GET /sessions`) and mount it in `apps/vhunambi_api/src/server.ts` under `/v1/auth`, `/api/auth`, and `/api/v1/auth`.

### Milestone `M61.3`: Atomic Payout Lock, Zero-Coin Exploit Closure & Tenant Delta-Sync
- [ ] **Task `61.3.1` (Wallet IDOR & `BEGIN IMMEDIATE` Lock)**: Wrap `VhunambiDatabase.requestPayout()` in `BEGIN IMMEDIATE ... COMMIT` with `ROLLBACK` on error, and wire `sovereignAuthMiddleware` + `assertTenantCreatorAccess` into `apps/vhunambi_api/src/routes/wallet_routes.ts` and `/creators/:id/wallet/*` in `social_routes.ts`.
- [ ] **Task `61.3.2` (Free Beat License Exploit Closure)**: Update `apps/vhunambi_api/src/routes/marketplace_routes.ts` and `marketplace_service.ts` so authenticated or strict-auth beat license purchases enforce `assertTenantCreatorAccess(c, body.buyerId)` and force `enforceWalletBalance: true` (blocking 0-coin buyouts with `402 INSUFFICIENT_WALLET_BALANCE`).
- [ ] **Task `61.3.3` (Library, Playlist & Delta-Sync Tenant Isolation)**: Enforce row ownership checks in `library_routes.ts` (`deleteLibraryItem` scoped by `creator_id`) and `playlist_routes.ts` (`getPlaylistOwnerCreatorId` check returning `403 TENANT_FORBIDDEN` on cross-tenant mutation), and scope `recordMutation` + `getDelta(sinceSeq, limit, viewerCreatorId)` + `POST /api/sync/mutations` in `sync_routes.ts` and `vhunambi_db.ts`.

### Milestone `M61.4`: Client Per-Device CSPRNG Salt, `vhunambi_tokens` & `SovereignApiClient`
- [ ] **Task `61.4.1` (`HiveAesVaultCipher` Per-Device Entropy)**: Upgrade `apps/vhunambi_client/lib/core/storage/hive_aes_vault_cipher.dart` and `hive_service.dart` with `ensureDeviceGenesisSalt()` (`Random.secure()` 32-byte base64url salt persisted in `vhunambi_prefs['sovereign_device_genesis_salt_v61']`).
- [ ] **Task `61.4.2` (`SovereignAuthSession` & `SovereignAuthRepository`)**: Create `apps/vhunambi_client/lib/core/auth/sovereign_auth_session.dart` and `sovereign_auth_repository.dart` to persist and restore encrypted sessions in `vhunambi_tokens` (`AppConstants.tokenBoxKey`).
- [ ] **Task `61.4.3` (`SovereignApiClient` & `AppConstants.resolveApiRootUrl()`)**: Add `resolveApiRootUrl()` to `app_constants.dart` and create `apps/vhunambi_client/lib/core/network/sovereign_api_client.dart` with automatic Bearer injection and single-flight `POST /api/auth/refresh` on `401`.

### Milestone `M61.5`: 6-Way Client Identity Unification & Multi-User Hive Sanitizer
- [ ] **Task `61.5.1` (`SovereignHiveAccountSanitizer`)**: Create `apps/vhunambi_client/lib/core/auth/sovereign_hive_account_sanitizer.dart` to purge private user boxes (`wallet_ledger`, `license_certificates`, `creator_dna`, `sync_outbox`, `library_tracks`, `playlists`, `profiles['profile_me']`, `edge_sync_last_seq`) on account switch or sign-out while preserving public catalog boxes.
- [ ] **Task `61.5.2` (`auth_providers.dart` & 6-Domain Wiring)**: Create `apps/vhunambi_client/lib/core/auth/auth_providers.dart` (`authSessionProvider`, `currentCreatorIdProvider`, `currentCreatorHandleProvider`), upgrade `creator_id_utils.dart` (`canonicalizeCreatorId`), and wire Playlists, Library, Creator Wallet, Marketplace Beat Checkout, Social/Reels Comments, and Content Studio/Owner Profile to `currentCreatorIdProvider`.

### Milestone `M61.6`: Obsidian Identity Security HUD, `SovereignAuthSheet` & Full-Stack Verification
- [ ] **Task `61.6.1` (`AccountIdentitySecurityCard` & `SovereignAuthSheet`)**: Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/account_identity_security_card.dart` and `apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart` (`STD-UIUX-001` compliant, zero emojis), and embed `AccountIdentitySecurityCard` inside `ProfileSettingsDrawer`.
- [ ] **Task `61.6.2` (Backend Phase 61 Integration Test Suite)**: Create `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` testing registration, login, `scrypt` verification, JWT validation, refresh rotation, token reuse family revocation, cross-tenant `403` IDOR blocking on Wallet/Library/Playlists/Marketplace, `402` zero-coin beat license exploit blocking, atomic `BEGIN IMMEDIATE` payouts, and tenant-scoped `/api/sync/delta`.
- [ ] **Task `61.6.3` (Client Phase 61 Auth, Vault, Sanitizer & HUD Tests)**: Create `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` and `apps/vhunambi_client/test/features/auth/sovereign_auth_hud_widget_test.dart`.
- [ ] **Task `61.6.4` (Full-Stack Regression & Zero-Analyzer Verification)**: Run all backend and client tests plus `flutter analyze` to confirm zero issues.

---

## 3. Requirement-to-Task-to-Test Traceability Matrix

| Requirement ID | Task IDs | Verification Test File | Gate |
| :--- | :--- | :--- | :--- |
| `REQ-P61-DB-01` .. `03` | `61.1.1`, `61.1.2`, `61.1.3` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01` |
| `REQ-P61-AUTH-01` .. `03` | `61.2.1`, `61.2.2` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-01`, `G-61-02`, `G-61-05` |
| `REQ-P61-SEC-01` .. `04` | `61.3.1`, `61.3.2`, `61.3.3` | `apps/vhunambi_api/test/phase61_sovereign_identity_auth_security.test.ts` | `G-61-02`, `G-61-03`, `G-61-04` |
| `REQ-P61-CLI-01` .. `05` | `61.4.1` .. `61.5.2` | `apps/vhunambi_client/test/features/auth/phase61_sovereign_auth_and_security_test.dart` | `G-61-06`, `G-61-07` |
| `REQ-P61-HUD-01` .. `02` | `61.6.1`, `61.6.3` | `apps/vhunambi_client/test/features/auth/sovereign_auth_hud_widget_test.dart` | `G-61-08` |

---

## 4. Anti-Bait-and-Switch Forensic Verification Checklist

1. **Zero Placeholder Code (`Law 1`)**: Verified zero occurrences of `// TODO`, `// ...`, `throw UnimplementedError`, or stubbed methods across `design.md`.
2. **100% Authentic Codebase Symbols (`Law 2`)**: Verified all imports use `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `AppColors`, `AppTypography`, and Hono/`node:sqlite`/`node:crypto`.
3. **Zero Emoji Contamination (`Law 3`)**: Verified zero raw Unicode emojis in Dart widget trees, code blocks, or formal tables (`STD-UIUX-001`).
4. **Mermaid Diagram Syntax Safety (`Law 4`)**: Verified only `stateDiagram-v2` and `sequenceDiagram` are used with clean labels and zero HTML tags.
5. **100% Legacy Test Backward Compatibility (`Law 5`)**: Verified `sovereignAuthMiddleware` enforces strict `401`/`403` when `Authorization` or `x-vhunambi-enforce-auth` is supplied while allowing unauthenticated legacy test suites (`phase58`, `phase59`, etc.) to pass without modification.
6. **Spec-Only Turn Compliance (`Law 6`)**: Verified zero `.dart` or `.ts` files in `apps/` were modified during specification authoring.

---

## 5. Stage 4 PowerShell Verification Commands (For Execution Turn)

```powershell
# 1. Verify Backend Phase 61 + All 17 Existing Backend Test Suites
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npm test

# 2. Verify Client Phase 61 Auth, Vault, Sanitizer & HUD Widget Tests
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter test test/features/auth/phase61_sovereign_auth_and_security_test.dart test/features/auth/sovereign_auth_hud_widget_test.dart

# 3. Verify Zero Dart Analyzer Warnings/Errors
flutter analyze
```

