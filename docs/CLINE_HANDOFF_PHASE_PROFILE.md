# System M8 Master Handoff: Profile UX Enhancement & Resilient Accessibility

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing System M8.
>
> **Generated At:** October 2026  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Baseline Health:** `dart analyze lib test` = **0 issues** | `flutter test` = **813/813 passing (100%)**  
> **Target Test Count:** **≥ 845 tests (≥ 32 new tests, 0 regressions)**

---

## 1. System Objectives & Scope

Modernize the Creator Profile and Studio management ecosystem into an accessible, resilient experience with robust offline-first fallbacks, retry policies, shimmer loading skeletons, and 44×44px touch ergonomics:

1. **Preserve `ArtistProfileEntity` Provider Return Type** — `artistProfileFamilyProvider` and `ownerProfileProvider` **MUST continue emitting `ArtistProfileEntity`**. Do NOT replace with a wrapper class. Manage network status, retries, and errors via the companion provider `profileOperationProvider` (`ProfileOperationState`).
2. **Resilient Network Layer** — `OperationResult<T>`, `NetworkErrorHandler`, and `RetryStrategy` with exponential backoff (max 3 retries, capped at 16s, 10s operation timeout).
3. **Token-Disciplined Shimmer Skeletons** — Compose `ShimmerBox` and `TrackTileSkeleton` from `lib/shared/widgets/shimmer_skeleton.dart`. **NEVER hardcode `#141418`** or build custom unmanaged animation loops.
4. **WCAG 2.1 AA Accessibility & Touch Targets** — Enforce minimum 44×44px hit bounds on all action pills, tip buttons, edit switches, and avatar triggers. Provide high-contrast focus borders and full screen reader semantics.
5. **Zero Regressions Guarantee** — All existing tests in `test/features/profile/presentation/providers/profile_notifier_test.dart` and `owner_profile_view_test.dart` MUST continue to pass cleanly.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere strictly to all 4 documents in `docs/phases/profile-ux-enhancement/`:

- [blueprint.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/profile-ux-enhancement/blueprint.md)
- [requirements.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/profile-ux-enhancement/requirements.md)
- [design.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/profile-ux-enhancement/design.md)
- [tasks.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/profile-ux-enhancement/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Provider Signature Integrity:** Never change `StateNotifierProvider.family<ArtistProfileNotifier, ArtistProfileEntity, String>` into a non-entity wrapper.
2. **Design Tokens Only:** Zero raw hex values. Strictly map to `AppColors.*` (`surfaceCanvas`, `surfaceElevated`, `brandPrimary`, `error`, etc.).
3. **Shimmer Engine Reuse:** Use `ShimmerBox` from `lib/shared/widgets/shimmer_skeleton.dart`.
4. **Ergonomic Touch Targets:** Minimum 44×44px touch bounding box on every interactive control.
5. **Zero Regressions:** All 813 baseline tests must stay green.

---

## 4. Key Target Files

### Files to CREATE
```
apps/vhunambi_client/lib/core/
  network/operation_result.dart
  network/error_handler.dart
  network/retry_strategy.dart
  network/network_operation.dart
apps/vhunambi_client/lib/features/profile/
  presentation/
    providers/profile_operation_provider.dart
    widgets/profile_skeleton_screen.dart
    widgets/profile_error_boundary.dart
apps/vhunambi_client/test/
  core/network/network_operation_test.dart
  features/profile/presentation/providers/profile_operation_provider_test.dart
  features/profile/presentation/widgets/profile_skeleton_screen_test.dart
  features/profile/presentation/widgets/profile_error_boundary_test.dart
```

### Files to MODIFY
```
apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart (bind companion provider & skeletons)
apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart (bind companion provider & error boundary)
```

---

## 5. Verification Commands

```powershell
cd apps/vhunambi_client
dart analyze lib test
flutter test test/features/profile/
flutter test
```
