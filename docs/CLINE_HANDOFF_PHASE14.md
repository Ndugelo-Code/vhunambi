# Phase 14 Master Handoff: Producer Beats Vault & Beatstore Listing Cockpit

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 14. Read this first — it captures exact requirements, architectural invariants, full class designs, known failure modes from previous phases, and the step-by-step execution checklist.
>
> **Generated At:** 2026-09-27T02:45:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Baseline:** `dart analyze .` = **0 issues** | `flutter test` = **541/541 passing (100%)**  
> **Target Test Count:** **≥ 576 tests (≥ 35 new tests, 0 regressions)**  

---

## 1. Phase 14 Objectives & Scope

Phase 14 closes the `/library?tab=beats` deferred loop from Phase 4 and completes the two-sided marketplace seller loop initiated in Phase 6.

In Phase 6, the Beats Marketplace (`/market`) delivered beat discovery, auditioning, and credit licensing. The seller monetization banner explicitly pointed creators to:
`[Go to Library -> ?tab=beats]` ("Sell your beats: Create instrumental beats and list them here. Every time someone licenses your beat, credits go straight to your balance.").

Phase 14 delivers the dedicated **Producer Beats Vault & Beatstore Listing Cockpit** at `/library?tab=beats`:
1. **Instrumental Beats Catalog:** High-density vault organizing user beats with regional genre gradients, BPM badges, musical key badges, and live preview auditions.
2. **Beat Authoring & Metadata Editing:** Create new beats or convert existing Library tracks into sellable beats with Title, Genre, BPM (tap-tempo & slider), Musical Key, Tags, Credit Pricing, and Licensing Tier.
3. **Bi-directional Marketplace Sync:** One-tap Publish / Unpublish toggle that immediately registers or removes the beat in `marketplaceBeatsProvider.notifier`.
4. **Stems Package Management:** 4-stem availability tracking (Drums, Bass, Melody, Other) and stem bundle ZIP manifest export simulation.
5. **Producer Sales & Royalty Ledger:** Historical sales records with buyer handle, timestamp, and credits earned, backed by a visual analytics banner (`BeatStatsBanner`).
6. **Library & Shell Mounting:** Seamless integration into `LibraryView` when `category == LibraryCategory.beats`.

---

## 2. Deliverables Table

| # | Deliverable | Target File |
| :--- | :--- | :--- |
| **1** | Constant `beatsBoxKey` | `lib/core/constants/app_constants.dart` |
| **2** | Enums & Domain Models (`BeatStatus`, `BeatLicenseTier`, `BeatStemPackage`, `BeatSaleRecord`, `ProducerBeatEntity`) | `lib/features/beats/domain/models/producer_beat_entity.dart` |
| **3** | Repository Interface (`IBeatRepository`) | `lib/features/beats/domain/repositories/i_beat_repository.dart` |
| **4** | In-Memory Repository Double (`InMemoryBeatRepository`) | `lib/features/beats/data/repositories/in_memory_beat_repository.dart` |
| **5** | Production Hive-Backed Repository (`BeatRepository`) | `lib/features/beats/data/repositories/beat_repository.dart` |
| **6** | Providers & Filter Engine (`BeatsNotifier`, `beatsProvider`, `beatsVaultFilterProvider`, `filteredBeatsVaultProvider`, `beatsVaultStatsProvider`) | `lib/features/beats/presentation/providers/beats_provider.dart` |
| **7** | Presentation Widgets (`BeatCard`, `BeatListTile`, `BeatStatusBadge`, `BeatStatsBanner`) | `lib/features/beats/presentation/widgets/` |
| **8** | Modals & Dialogs (`BeatFormDialog`, `PublishBeatModal`, `StemExportModal`) | `lib/features/beats/presentation/widgets/` |
| **9** | Primary Vault Screen (`BeatsVaultView`) | `lib/features/beats/presentation/views/beats_vault_view.dart` |
| **10** | Detailed Beat Cockpit (`BeatDetailCockpitView`) | `lib/features/beats/presentation/views/beat_detail_cockpit_view.dart` |
| **11** | Library Mounting & Marketplace Cross-Sync | `lib/features/library/presentation/views/library_view.dart` |
| **12** | Automated Test Suites (≥ 35 new tests) | `test/features/beats/` (5 test suites) |

---

## 3. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_14_beats_vault/`:
- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_14_beats_vault/blueprint.md) — Visual geometry, layout diagrams, tokens, state machines.
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_14_beats_vault/requirements.md) — RFC 2119 / EARS requirements (`REQ-BEAT-01` to `REQ-BEAT-25`).
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_14_beats_vault/design.md) — Exact Dart class signatures, Riverpod providers, widget trees, token mapping.
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_14_beats_vault/tasks.md) — 13-task sequenced checklist with pre-flight and verification gates.

---

## 4. Codebase Invariants & Non-Negotiable Rules

1. **Zero Raw Hex Values:**
   - Always use `AppColors.*` (`surfaceCanvas`, `surfaceElevated`, `surfaceSecondary`, `surfaceModal`, `brandPrimary`, `brandContrast`, `borderSubtle`, `textPrimary`, `textSecondary`, `textTertiary`, `badgeCyanBg`, `badgeCyan`, `amberInset`, `success`, `error`).
   - Never hardcode `#0A0A0C`, `#141418`, `#F97316`, or raw hex strings.
2. **Typography Tokens Only:**
   - Use only valid getters on `AppTypography`: `displayLarge`, `displayMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMuted`, `bodySmall`, `caption`, `badge`.
   - **DO NOT** use `bodyMedium`, `button`, or `titleSmall` — they do not exist!
3. **Spacing & Radii:**
   - `AppSpacing`: `xxs` (4), `xs` (8), `sm` (12), `md` (16), `lg` (20), `xl` (24), `xxl` (32).
   - `AppRadius`: `card` (16), `cardBorder`, `input` (12), `inputBorder`, `modal` (24), `modalBorder`, `pill` (9999), `pillBorder`, `squircle` (14).
4. **ListTile Material Wrapper:**
   - Wrap any colored `ListTile` in `Material(color: AppColors.surfaceElevated, shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: BorderSide(color: AppColors.borderSubtle)), child: ListTile(...))`.
   - Never use `Container(decoration: BoxDecoration(...), child: ListTile(...))` (causes ink splash clipping errors).
5. **State Management:**
   - Flutter Riverpod 2.x only (`StateNotifierProvider`, `Provider`, `StateProvider`). Do NOT use Riverpod 3 `@riverpod` annotations or `Notifier`.
6. **Headless Hive Persistence Safety:**
   - Check `Hive.isBoxOpen(AppConstants.beatsBoxKey)` before access; if false, store to `_inMemoryFallback` map. Never call un-awaited `Hive.openBox()` during synchronous constructor/init.
7. **Player Integration:**
   - Trigger playback via: `ref.read(playerStateProvider.notifier).playTrack(track)`. (`playerNotifierProvider` does not exist).
8. **Responsive Columns:**
   - Derive columns: `ResponsiveUtils.isMobile(context) ? 2 : ResponsiveUtils.isTablet(context) ? 3 : 4`. (Do not use `ResponsiveUtils.gridColumns()` which returns 6/2).

---

## 5. Exact Class Signatures

### Domain Aggregate (`ProducerBeatEntity`)

```dart
enum BeatStatus { draft, published, archived }

enum BeatLicenseTier { nonExclusiveCommercial, exclusiveOwnership, syncLicense, personalLease }

class BeatStemPackage {
  final String? drumsUrl;
  final String? bassUrl;
  final String? melodyUrl;
  final String? otherUrl;
  final bool isSeparated;
  const BeatStemPackage({...});
  int get stemCount;
  bool get hasAllStems;
  Map<String, dynamic> toJson();
  factory BeatStemPackage.fromJson(Map<String, dynamic> json);
}

class BeatSaleRecord {
  final String saleId;
  final String buyerId;
  final String buyerHandle;
  final BeatLicenseTier licenseTier;
  final int creditsEarned;
  final DateTime timestamp;
  const BeatSaleRecord({...});
  Map<String, dynamic> toJson();
  factory BeatSaleRecord.fromJson(Map<String, dynamic> json);
}

class ProducerBeatEntity {
  final String id;
  final String? trackId;
  final String title;
  final String producerId;
  final String producerName;
  final String producerHandle;
  final String genre;
  final int bpm;
  final String musicalKey;
  final List<String> tags;
  final int priceInCredits;
  final BeatLicenseTier licenseTier;
  final BeatStatus status;
  final String previewAudioUrl;
  final BeatStemPackage stemPackage;
  final List<BeatSaleRecord> salesRecords;
  final int auditionCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProducerBeatEntity({...});

  bool get isPublished;
  bool get isDraft;
  bool get isArchived;
  int get totalSales;
  int get totalEarningsCredits;
  String get bpmLabel;
  String get priceLabel;
  String get statusLabel;
  String get keyLabel;

  ProducerBeatEntity copyWith({...});
  Map<String, dynamic> toJson();
  factory ProducerBeatEntity.fromJson(Map<String, dynamic> json);
}
```

### Providers

```dart
final beatRepositoryProvider = Provider<IBeatRepository>((ref) => BeatRepository());

final beatsProvider = StateNotifierProvider<BeatsNotifier, List<ProducerBeatEntity>>(
  (ref) => BeatsNotifier(ref.watch(beatRepositoryProvider)),
);

final beatsVaultFilterProvider = StateProvider<BeatsVaultFilterState>(
  (ref) => const BeatsVaultFilterState(),
);

final filteredBeatsVaultProvider = Provider<List<ProducerBeatEntity>>((ref) {
  final beats = ref.watch(beatsProvider);
  final filter = ref.watch(beatsVaultFilterProvider);
  return filterBeatsVault(beats: beats, filter: filter);
});

final beatsVaultStatsProvider = Provider<BeatsVaultStats>((ref) {
  final beats = ref.watch(beatsProvider);
  return calculateBeatsStats(beats);
});
```

---

## 6. Known Failure Modes From Previous Phases (Must Avoid)

| # | Trap | Manifestation | Prevention / Solution |
| :--- | :--- | :--- | :--- |
| **1** | `Container(BoxDecoration)` wrapping `ListTile` | Ink splashes overflow, crash in strict render tests | Always wrap with `Material(color: ..., shape: RoundedRectangleBorder(...), child: ListTile(...))` |
| **2** | Headless Hive access in test runner | `HiveError: Box not found` or unhandled zone crash | Verify `Hive.isBoxOpen(key)` first; fall back to internal `Map<String, dynamic>` |
| **3** | `AppTypography.bodyMedium` or `button` | Compile error: `getter not found` | Use `AppTypography.bodyLarge`, `bodySmall`, or `caption` |
| **4** | Using `playerNotifierProvider` | Compile error: `undefined identifier` | Use `playerStateProvider.notifier.playTrack(...)` |
| **5** | Using `ResponsiveUtils.gridColumns()` | Returns 6 (desktop) or 2 (mobile), distorting card ratio | Calculate `isMobile ? 2 : isTablet ? 3 : 4` explicitly |
| **6** | Reorderable list item without key | `Every item of ReorderableListView must have a key` | Pass `ValueKey('...')` to the outermost widget returned by `itemBuilder` |
| **7** | Deprecated `onReorder` or parameter count bug | Flutter 3.44+ compiler warning or runtime error | Use `onReorderItem: (oldIndex, newIndex) { ... }` |

---

## 7. Minimal Test Scaffold Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/beats/domain/models/producer_beat_entity.dart';
import 'package:vhunambi_client/features/beats/data/repositories/in_memory_beat_repository.dart';
import 'package:vhunambi_client/features/beats/presentation/providers/beats_provider.dart';

void main() {
  group('BeatsNotifier', () {
    test('loads seeded beats and publishes to market', () async {
      final repo = InMemoryBeatRepository();
      final container = ProviderContainer(
        overrides: [
          beatRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      final initial = container.read(beatsProvider);
      expect(initial.length, greaterThanOrEqualTo(3));

      final draft = initial.firstWhere((b) => b.isDraft);
      await notifier.publishToMarket(draft.id);

      final updated = container.read(beatsProvider);
      final published = updated.firstWhere((b) => b.id == draft.id);
      expect(published.isPublished, isTrue);
    });
  });
}
```

---

## 8. Execution Checklist

- [ ] **Step 1:** Run pre-flight checks: `dart analyze .` (0 issues) and `flutter test --no-pub` (541/541 passing).
- [ ] **Step 2 (Task 1):** Add `beatsBoxKey` to `lib/core/constants/app_constants.dart`.
- [ ] **Step 3 (Task 2):** Create `lib/features/beats/domain/models/producer_beat_entity.dart`.
- [ ] **Step 4 (Task 3):** Create `lib/features/beats/domain/repositories/i_beat_repository.dart`.
- [ ] **Step 5 (Tasks 4 & 5):** Create `in_memory_beat_repository.dart` and `beat_repository.dart`.
- [ ] **Step 6 (Task 6):** Create `lib/features/beats/presentation/providers/beats_provider.dart`.
- [ ] **Step 7 (Task 7):** Create `beat_status_badge.dart`, `beat_stats_banner.dart`, `beat_card.dart`, `beat_list_tile.dart`.
- [ ] **Step 8 (Task 8):** Create `beat_form_dialog.dart`, `publish_beat_modal.dart`, `stem_export_modal.dart`.
- [ ] **Step 9 (Task 9):** Create `lib/features/beats/presentation/views/beats_vault_view.dart`.
- [ ] **Step 10 (Task 10):** Create `lib/features/beats/presentation/views/beat_detail_cockpit_view.dart`.
- [ ] **Step 11 (Task 11):** Mount `BeatsVaultView` in `lib/features/library/presentation/views/library_view.dart` for `category == LibraryCategory.beats`.
- [ ] **Step 12 (Task 12):** Write unit & widget tests in `test/features/beats/` (≥ 35 new tests).
- [ ] **Step 13 (Task 13):** Run `dart analyze .` (0 issues) and `flutter test --no-pub` (≥ 576 passing tests).
- [ ] **Step 14:** Author `docs/phases/phase_14_beats_vault/walkthrough.md` and update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.

---

## 9. Final Verification Gates

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client

# 1. Static Analysis Gate
dart analyze .
# MUST report: Analyzing .... No issues found! (0 issues)

# 2. Automated Test Suite
flutter test --no-pub
# MUST report: All tests passed! (100% — target: ≥ 576 passing tests)
```
