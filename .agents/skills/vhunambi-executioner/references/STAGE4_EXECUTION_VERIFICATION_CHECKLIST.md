# Stage 4 Execution & Anti-Trap Verification Checklist (`vhunambi-executioner`)

Run through this 18-point forensic checklist during every Milestone Micro-Gate and before closing out Stage 4 execution.

---

## A. Pre-Edit File Preservation & Cross-Phase Bridge Checks

- [ ] **1. Existing File Read Before Edit**: Did I call `read_file` on every existing target file before modifying it, and did I use `edit_file` (surgical additive edit) rather than blindly overwriting the entire file with a partial `design.md` snippet?
- [ ] **2. `AppConstants` 26-Box & Layout Metric Preservation (`apps/vhunambi_client/lib/core/constants/app_constants.dart`)**: Are all 26 Phase 60 Hive box key constants (`prefsBoxKey`, `tokenBoxKey`, `tracksBoxKey`, `walletLedgerBoxKey`, `walletTransactionsBoxKey`, `payoutMethodsBoxKey`, `beatLicenseContractsBoxKey`, `royaltySplitsBoxKey`, `outboxMutationsBoxKey`, `stemDspRecipesBoxKey`, etc.) plus layout constants (`desktopBreakpoint`, `tabletBreakpoint`, `bottomNavHeight`, `miniPlayerHeight`) still intact?
- [ ] **3. `HiveAesVaultCipher` Dual-Signature Parity (`apps/vhunambi_client/lib/core/storage/hive_aes_vault_cipher.dart`)**: Does `HiveAesVaultCipher` expose both `createCipher({...})` and `buildCipher({...})` so both Phase 60 (`SovereignHiveBootstrapService`) and Phase 61+ callers compile cleanly?
- [ ] **4. `SovereignHiveAccountSanitizer` Static L1 Cache Purge (`apps/vhunambi_client/lib/core/storage/sovereign_hive_account_sanitizer.dart`)**: Does `sanitizeForAccountTransition()` clear both the user-scoped Hive boxes AND the static L1 in-memory caches (`WalletLedgerRepository.clearForTesting()`, `PlaybackSessionRepository.clearForTesting()`, `StemDspRecipeRepository.clearForTesting()`, and resetting `SovereignPrefsRepository.saveEdgeSyncCursor(lastServerSeq: 0, ...)`), while preserving `'onboarding_state_v1'` inside `vhunambi_tokens`?
- [ ] **5. `CreatorIdUtils` Lexical Scope Guard (`apps/vhunambi_client/lib/core/utils/creator_id_utils.dart`)**: Do both the top-level functions (`normalizeCreatorId`, `canonicalizeCreatorId`, `handleFromCreatorId`) and the static `CreatorIdUtils` class methods delegate to private `_...Impl` helpers so static methods never recursively call themselves?
- [ ] **6. `vhunambi_db.ts` Method & Column Preservation (`apps/vhunambi_api/src/db/vhunambi_db.ts`)**: Are both `getWallet(creatorId)` and `getWalletSnapshot(creatorId)` preserved, and does `user_library_sync` retain `data_json` alongside any new columns (`tracks_json`, `playlists_json`, `favorites_json`)?
- [ ] **7. Cloudflare Workers (`workerd`) V8 Isolate Guards (`apps/vhunambi_api`)**: Are all `node:sqlite` (`DatabaseSync`), `fs`, and `process.uptime()` / `process.memoryUsage()` usages guarded by `isNodeSqliteAvailable()` or `typeof process` checks so `src/worker.ts` boots cleanly on Cloudflare Workers without throwing `ERR_UNKNOWN_BUILTIN_MODULE`?

---

## B. Zero-Lazy-Code & UI/UX Token Integrity Checks (`STD-UIUX-001`)

- [ ] **8. Zero Placeholders or Summary Stubs**: Have I verified there are zero `// TODO`, `// FIXME`, `// ...`, `throw UnimplementedError()`, or stubbed methods anywhere in the created/modified files?
- [ ] **9. Authentic Package Imports**: Do all Flutter imports use `package:vhunambi_client/...` (never `package:vhunambi/...`) and `package:phosphor_icons/phosphor_icons.dart` (never `package:phosphor_flutter/...`)?
- [ ] **10. Zero Raw Unicode Emojis (`STD-UIUX-001`)**: Are all UI strings, status pills, comments, and logs 100% free of raw Unicode emojis, using `PhosphorIcon(...)` vector glyphs instead?
- [ ] **11. Authentic `AppColors` & `AppTypography` Tokens**: Do all widgets reference valid `AppColors.*` and `AppTypography.*` getters without inventing nonexistent names (`obsidianBg`, `surfaceCard`, `labelSmall`, `labelMedium`)?
- [ ] **12. Exact `Key('...')` Contract Parity**: Does every interactive control, text field, badge, and status pill carry the exact `Key('...')` string mandated by `requirements.md` and `design.md`?
- [ ] **13. $44 \times 44\text{dp}$ Touch Target Minimum**: Are all interactive buttons, chips, and icon actions wrapped in or configured with a minimum $44 \times 44\text{dp}$ hit area?

---

## C. Anti-Hang Test & Verification Gate Checks

- [ ] **14. Zero Unbounded `pumpAndSettle()` Calls on Animated Trees**: Do all widget tests on animated screens/drawers use bounded `await tester.pump(const Duration(milliseconds: 300))` steps instead of `await tester.pumpAndSettle()`?
- [ ] **15. Zero Live Network Waits in Tests**: Are all HTTP/WebSocket calls in unit and widget tests backed by deterministic in-memory fakes or mock adapters (zero 15s–30s live socket hangs)?
- [ ] **16. Bounded Test Execution (`--timeout=60s`)**: Did I run each milestone's Flutter test file with `flutter test <test_path> --timeout=60s` and confirm it passes in seconds?
- [ ] **17. Static Analysis Clean (`0 issues`)**:
  - `apps/vhunambi_api`: `npm run build` (`tsc --noEmit`) exits `0`.
  - `apps/vhunambi_client`: `flutter analyze` reports `No issues found!`.
  - `tools/zr-studio-gpu` (if touched): `python -m py_compile handler.py` exits `0`.
- [ ] **18. `tasks.md` Progress Synchronization**: Are all completed milestones and sub-tasks marked `[x]` in the phase's `tasks.md`?

