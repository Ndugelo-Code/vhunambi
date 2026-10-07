# Phase 13 Master Handoff: Collections & EP/Album Concept Bundler

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 13. Read this first — it captures exact requirements, architectural invariants, full class designs, known failure modes from previous phases, and the execution checklist.
>
> **Generated At:** 2026-09-27T01:33:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Baseline:** `dart analyze .` = **0 issues** | `flutter test` = **477/477 passing (100%)**  
> **Target Test Count:** **≥ 512 tests (≥ 35 new tests)**

---

## 1. Phase 13 Objectives & Scope

Phase 13 closes the `/library?tab=collections` deferred loop from Phase 4. It delivers the **Collections Bundler**: a structured content creation layer that lets artists group generated tracks into EPs, albums, singles, and concept projects with unified artwork, release metadata, and split-sheet participant attribution.

### Deliverables

| # | Deliverable | Files |
| :--- | :--- | :--- |
| 1 | `collectionsBoxKey` constant | `lib/core/constants/app_constants.dart` |
| 2 | `CollectionType` enum + `SplitParticipant` + `CollectionEntity` models | `lib/features/collections/domain/models/collection_entity.dart` |
| 3 | `ICollectionRepository` interface | `lib/features/collections/domain/repositories/i_collection_repository.dart` |
| 4 | `InMemoryCollectionRepository` | `lib/features/collections/data/repositories/in_memory_collection_repository.dart` |
| 5 | `CollectionRepository` (Hive-backed) | `lib/features/collections/data/repositories/collection_repository.dart` |
| 6 | `collectionsProvider` + `CollectionsNotifier` | `lib/features/collections/presentation/providers/collections_provider.dart` |
| 7 | `CollectionsVaultView` (grid/list/empty/create/rename/delete) | `lib/features/collections/presentation/views/collections_vault_view.dart` |
| 8 | `CollectionDetailView` (tracks, reorder, add, split sheet) | `lib/features/collections/presentation/views/collection_detail_view.dart` |
| 9 | Library tab integration | `lib/features/library/presentation/views/library_view.dart` |
| 10 | Automated tests (≥35) | `test/features/collections/` |

---

## 2. Specification Documents (Single Source of Truth)

Read all 4 documents in `docs/phases/phase_13_collections_bundler/` before writing any code:

- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_13_collections_bundler/blueprint.md) — Layout geometry, state machine, visual tokens, collection type constraints.
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_13_collections_bundler/requirements.md) — EARS/RFC 2119 requirements (REQ-COL-01 through REQ-COL-33).
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_13_collections_bundler/design.md) — Exact class signatures, Riverpod providers, widget trees, token mapping.
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_13_collections_bundler/tasks.md) — Sequenced 13-task execution checklist with pre-flight and verification gates.

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`. No `Color(0xFF...)` in feature code.
2. **Riverpod 2.x Only:** Use `StateNotifierProvider`, `Provider`. No `ChangeNotifier`, no `Notifier`-style API.
3. **`Material` Wraps `ListTile`:** Never wrap `ListTile` with a `Container(decoration: BoxDecoration(color: ...))`. Always use `Material(color: ..., shape: RoundedRectangleBorder(...))`. Violation causes Flutter framework assertion: *"ListTile background color or ink splashes may be invisible."*
4. **`hive_flutter` import:** Always `import 'package:hive_flutter/hive_flutter.dart'`, never `import 'package:hive/hive.dart'` — the latter triggers `depend_on_referenced_packages` analyzer info.
5. **`ReorderableListView` — use `onReorderEnd` not `onReorder`:** `onReorder` is deprecated since Flutter v3.41.0. Use `onReorderEnd`.
6. **Typography tokens only:** Use getters from `AppTypography`: `displayLarge`, `displayMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMuted`, `bodySmall`, `caption`, `badge`. `bodyMedium`, `button`, `titleSmall` DO NOT EXIST.
7. **Headless Hive Safety:** `CollectionRepository` MUST NOT call `Hive.openBox()` unconditionally. Instead, check `Hive.isBoxOpen(key)` first. When Hive is uninitialized, fall back to `_inMemoryFallback` map silently. See `playlist_repository.dart` for the exact pattern.
8. **Test Provider Overrides:** `collectionsProvider` is `StateNotifierProvider<CollectionsNotifier, List<CollectionEntity>>`. Cannot be overridden with a plain list. Override `collectionRepositoryProvider` with `InMemoryCollectionRepository` instead.

---

## 4. Exact Class Signatures to Implement

### `CollectionType` (in `collection_entity.dart`)
```dart
enum CollectionType {
  single, ep, album, conceptProject;

  String get label;                      // 'Single' | 'EP' | 'Album' | 'Concept Project'
  (int, int) get recommendedRange;       // (1,1) | (2,7) | (8,20) | (1,30)
  String toJson();                       // 'single' | 'ep' | 'album' | 'concept_project'
  static CollectionType fromJson(String);
}
```

### `SplitParticipant` (in `collection_entity.dart`)
```dart
@immutable
class SplitParticipant {
  final String name;
  final String role;
  final double sharePercent;

  const SplitParticipant({required this.name, required this.role, required this.sharePercent});
  SplitParticipant copyWith({String? name, String? role, double? sharePercent});
  Map<String, dynamic> toJson();         // keys: 'name', 'role', 'share_percent'
  factory SplitParticipant.fromJson(Map<String, dynamic>);
  @override bool operator ==(Object other);
  @override int get hashCode;
}
```

### `CollectionEntity` (in `collection_entity.dart`)
```dart
@immutable
class CollectionEntity {
  final String id;
  final String title;
  final CollectionType type;
  final String genre;
  final String description;
  final DateTime? releaseDate;
  final String? coverImageUrl;
  final List<String> trackIds;
  final List<SplitParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectionEntity({
    required this.id,
    required this.title,
    this.type = CollectionType.ep,
    this.genre = '',
    this.description = '',
    this.releaseDate,
    this.coverImageUrl,
    this.trackIds = const [],
    this.participants = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get trackCount;
  double get totalSharePercent;
  bool get isSplitBalanced;
  String get typeLabel;

  CollectionEntity copyWith({...});
  Map<String, dynamic> toJson();         // snake_case keys + type.toJson() + releaseDate?.toIso8601String()
  factory CollectionEntity.fromJson(Map<String, dynamic>);
  @override bool operator ==(Object other);
  @override int get hashCode;
}
```

### `CollectionsNotifier` key ID generation
```dart
final now = DateTime.now();
final collection = CollectionEntity(
  id: 'col_${now.microsecondsSinceEpoch}',
  ...
  createdAt: now,
  updatedAt: now,
);
```

---

## 5. Library Integration — Exact Code Change

In `lib/features/library/presentation/views/library_view.dart`, change the `Expanded` child from:

```dart
child: category == LibraryCategory.playlists
    ? PlaylistsVaultView(onCreateRequested: onCreateRequested)
    : Column( ... ),
```

to:

```dart
child: category == LibraryCategory.playlists
    ? PlaylistsVaultView(onCreateRequested: onCreateRequested)
    : category == LibraryCategory.collections
        ? CollectionsVaultView(onCreateRequested: onCreateRequested)
        : Column( ... ),
```

Import: `import '../../../collections/presentation/views/collections_vault_view.dart';`

---

## 6. Known Failure Modes from Previous Phases

### Failure Mode A: `ListTile` Flutter assertion
**Symptom:** `ListTile background color or ink splashes may be invisible.`  
**Cause:** Wrapping `ListTile` in `Container(decoration: BoxDecoration(color: ...))`.  
**Fix:** Replace with `Material(color: AppColors.surfaceElevated, shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: BorderSide(color: AppColors.borderSubtle)))`.

### Failure Mode B: `depend_on_referenced_packages` analyzer info
**Symptom:** `info - The imported package 'hive' isn't a dependency of the importing package.`  
**Cause:** Using `import 'package:hive/hive.dart'` instead of `hive_flutter`.  
**Fix:** Always `import 'package:hive_flutter/hive_flutter.dart'` in both lib and test files.

### Failure Mode C: `prefer_initializing_formals` analyzer info
**Symptom:** `info - Use an initializing formal to assign a parameter to a field.`  
**Cause:** `Constructor({Box? box}) : _box = box;` when `_box` is non-final.  
**Fix:** Use constructor body: `Constructor({Box? box}) { _box = box; }`.

### Failure Mode D: Unhandled Hive async exception in tests
**Symptom:** Test suite reports unhandled zone exception from Hive's internal completer.  
**Cause:** Calling `Hive.openBox()` without first calling `Hive.init()`.  
**Fix:** Never call `Hive.openBox()` unconditionally. Guard with `Hive.isBoxOpen(key)` check or inject a pre-opened box.

### Failure Mode E: Wrong `ReorderableListView` callback
**Symptom:** Analyzer deprecation warning or runtime error.  
**Cause:** Using deprecated `onReorder` callback.  
**Fix:** Use `onReorderEnd` (Flutter ≥3.41).

### Failure Mode F: Hardcoded hex values
**Symptom:** `dart analyze` clean but design rules violated.  
**Cause:** `Color(0xFF...)` in widget files.  
**Fix:** Use `AppColors.*` tokens exclusively.

---

## 7. Test Scaffold Examples

### Provider Override (correct pattern)
```dart
Widget _buildTestWidget({
  required InMemoryCollectionRepository repository,
  LibraryViewMode viewMode = LibraryViewMode.grid,
}) {
  return ProviderScope(
    overrides: [
      collectionRepositoryProvider.overrideWithValue(repository),
      libraryViewModeProvider.overrideWith((ref) => viewMode),
    ],
    child: const MaterialApp(
      home: Scaffold(body: CollectionsVaultView()),
    ),
  );
}
```

### Domain model test pattern
```dart
test('CollectionType.ep has correct label and range', () {
  expect(CollectionType.ep.label, equals('EP'));
  expect(CollectionType.ep.recommendedRange, equals((2, 7)));
  expect(CollectionType.ep.toJson(), equals('ep'));
  expect(CollectionType.fromJson('ep'), equals(CollectionType.ep));
});
```

### Provider test with `ProviderContainer`
```dart
test('createCollection persists and prepends', () async {
  final repo = InMemoryCollectionRepository();
  final container = ProviderContainer(
    overrides: [collectionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);

  await container.read(collectionsProvider.notifier).createCollection(
    'My EP',
    CollectionType.ep,
    genre: 'Amapiano',
  );

  final state = container.read(collectionsProvider);
  expect(state.length, equals(1));
  expect(state.first.title, equals('My EP'));
  expect(state.first.genre, equals('Amapiano'));
  expect(state.first.type, equals(CollectionType.ep));
});
```

---

## 8. Execution Order

Execute tasks **strictly in order** — each task produces the code the next task depends on:

```
T1 → Constants
T2 → Domain models
T3 → Interface
T4 → InMemoryCollectionRepository
T5 → CollectionRepository
T6 → Providers
T7 → CollectionsVaultView
T8 → CollectionDetailView
T9 → AddToCollectionSheet (inline in T8)
T10 → AddParticipantDialog (inline in T8)
T11 → SplitSheetModal (inline in T8)
T12 → Library integration
T13 → Tests
```

After T13 passes all gates:
1. Write `docs/phases/phase_13_collections_bundler/walkthrough.md`.
2. Update `docs/AGENT_HANDOFF_BIBLE.md` header and append Phase 13 delivery record.
3. Update `README.md` status banner and milestone table.

---

## 9. Final Verification Gate

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client

dart analyze .
# Expected: No issues found! (0 issues)

flutter test --no-pub
# Expected: ≥ 512 tests passed! (0 failures, 0 regressions)
```

**HALT if either gate fails. Do not proceed to sign-off until both pass.**
