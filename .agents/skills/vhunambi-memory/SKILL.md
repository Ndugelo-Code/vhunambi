---
name: vhunambi-memory
description: >-
  Manages the Vhunambi Codebase Brain (Hippocampus memory.md files, Cortex
  CORTEX_INDEX.md, and Connectome CONNECTOME_GRAPH.json) via zero-dependency
  Node 24 CLI scripts. Use this skill at session start (WAKE), during phase
  specification drafting (ACTIVE), and after Stage 4 verification passes
  (SLEEP & DREAM) to preserve cross-session architectural breakthroughs,
  surface OPEN backend/client endpoints, and map 1-hop close and 2-hop distant
  Concept Hub relationships without scanning 70+ phase folders.
---

# Vhunambi Codebase Brain (`vhunambi-memory`)

Stateless LLM sessions wipe working context on refresh. Reading 74+ folders in `docs/phases/` (~100,000 lines) burns context and misses un-spec'd sprints. `vhunambi-memory` solves this with a 3-layer external memory architecture:

```text
  [HIPPOCAMPUS]  docs/phases/phase_XX_<name>/memory.md  +  docs/memory/sprints/P<id>_memory.md
       │
       │  (SLEEP: node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs)
       ▼
  [CONNECTOME]   docs/memory/CONNECTOME_GRAPH.json  (flat machine-readable graph, < 50ms query)
       │
       ├──► [CORTEX]  docs/memory/CORTEX_INDEX.md   (compact briefing read on every WAKE)
       └──► [DREAM]   Console Synergy & Ripple Report (flags stale OPEN hooks & hub synergies)
```

---

## 1. The Biological Wake / Active / Sleep & Dream Loop

### Phase A — WAKE (Session Start)
Before running broad greps, drafting specs, or writing code:
1. Read [`docs/memory/CORTEX_INDEX.md`](../../../docs/memory/CORTEX_INDEX.md).
2. Query the Connectome with zero LLM tokens:
   ```powershell
   node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open
   node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --hubs identity_role,media_artwork,mood_taxonomy,social_graph
   node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --file track_detail_view.dart
   ```
3. Inspect only the exact `code_anchor` and `spec_anchor` files returned by the query.

### Phase B — ACTIVE (During `/vhunambi-spec-architect` & `/vhunambi-executioner`)
- **`/vhunambi-spec-architect` (5-Document Standard):** Draft `docs/phases/phase_XX_<name>/memory.md` with `"status": "draft"`, declaring `consumes` (existing endpoint IDs the phase plugs into) and `endpoints` (new endpoints/primitives the phase introduces).
- **`/vhunambi-executioner` (Grounded Evidence Only):** Never narrate unverified memory. Update `memory.md` **only after** `flutter analyze`, `npx tsc --noEmit`, and test suites pass—recording verified `code_anchor` paths, real architectural breakthroughs, and verified dead ends/gotchas.
- **Un-spec'd Sprints / Hotfixes:** Write `docs/memory/sprints/P<id>_memory.md` using the identical schema so fast fixes (like `P66` or `P68.5`) never disappear from institutional memory.

### Phase C — SLEEP & DREAM (Session Close Consolidation)
Run the deterministic consolidator after verification gates pass:
```powershell
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```
This script:
1. Parses and validates all `docs/phases/*/memory.md` and `docs/memory/sprints/*.md` JSON metadata blocks.
2. Merges `consumers` across phases and automatically promotes any `OPEN` endpoint to `CONNECTED_EXTENSIBLE` once a `completed` phase declares it in `consumes`.
3. Rebuilds [`docs/memory/CONNECTOME_GRAPH.json`](../../../docs/memory/CONNECTOME_GRAPH.json) and regenerates [`docs/memory/CORTEX_INDEX.md`](../../../docs/memory/CORTEX_INDEX.md).
4. Runs the **DREAM Pass**, printing stale `OPEN` endpoints (older than 2 phases) and distant `CONNECTED_EXTENSIBLE` hub synergies relative to the latest completed phase.

---

## 2. Endpoint Lifecycle States & Relationship Classes

### 3 Endpoint Lifecycle States
| State | Meaning | Transition Rule |
| :--- | :--- | :--- |
| **`OPEN`** | Built/exposed on backend or client, **zero** downstream consumers yet. Stays surfaced in `CORTEX_INDEX.md` until claimed. | Automatically promoted to `CONNECTED_EXTENSIBLE` when a `completed` phase lists its ID in `consumes`. |
| **`CONNECTED_EXTENSIBLE`** | Wired to $\ge 1$ consumer, still active for future phases to adopt, subscribe to, or extend. | Accumulates every new claiming phase in `consumers[]`. |
| **`SEALED`** | One-off migration, disk scrubber, webhook, or internal helper closed to external feature coupling. | Excluded from default `--hubs` synergy views unless `--include-sealed` is passed. |

### 2 Relationship Classes
1. **1-Hop Close Direct Edges (`edges[]`):** Explicit structural couplings (`PROVIDES`, `CONSUMES`, `ROUTES_TO`, `MUTATES`, `INVALIDATES`) between concrete files, widgets, providers, or routes. Surfaced immediately by `--file <substring>`.
2. **2-Hop Distant Systemic Relatives (`concept_hubs[]` / `hubs[]`):** Semantic neighborhood tags from the 10 fixed Concept Hubs in [`docs/memory/CONCEPT_HUBS.md`](../../../docs/memory/CONCEPT_HUBS.md). Surfaced across distant phases by `--hubs <list>`.

---

## 3. Canonical `memory.md` Schema (Zero-Dependency Fenced JSON)

Every `memory.md` (and `docs/memory/sprints/P<id>_memory.md`) MUST begin with a fenced ```` ```json vhunambi-memory ```` metadata block (valid strict JSON parsed natively by Node 24 with zero npm dependencies), followed by concise human-readable Markdown:

````markdown
```json vhunambi-memory
{
  "phase_id": "P70",
  "memory_key": "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
  "title": "Song Cockpit & Visitor Creator Profile Overhaul",
  "status": "draft",
  "completed_at": null,
  "predecessor_keys": ["MEM-P68-HOME-MAIN-ROOM", "MEM-P69-KINETIC-POST-FOCUS"],
  "concept_hubs": ["identity_role", "media_artwork", "mood_taxonomy", "social_graph"],
  "consumes": ["EP-P68-TRACK-ARTWORK", "EP-P69-THREADED-COMMENTS", "EP-P58-MKT-VERIFY-PRODUCER"],
  "endpoints": [
    {
      "id": "EP-P70-EXAMPLE",
      "kind": "ui_primitive",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_70_.../design.md#section-2",
      "code_anchor": "apps/vhunambi_client/lib/core/widgets/example.dart",
      "consumers": ["P70:TrackDetailView"],
      "open_opportunities": "Adopt across Explore headers & Notifications sheet"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P69-THREADED-COMMENTS",
      "note": "Replaces flat track comments with shared threaded discussion"
    }
  ],
  "breakthroughs": [
    "One-line verified architectural breakthrough future agents must preserve."
  ],
  "gotchas": [
    "One-line verified dead end or hardware trap never to repeat."
  ]
}
```

# Phase 70 Session Memory & Breakthroughs

## 1. Core Architectural Breakthroughs
...

## 2. Close & Distant Connections Wired
...

## 3. Verified Dead Ends & Gotchas
...
````

### CLI Reference
```powershell
# Rebuild CONNECTOME_GRAPH.json + CORTEX_INDEX.md + Dream Ripple Report
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs

# List all OPEN unwired endpoints across the monorepo
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open

# Query by Concept Hubs (1-hop & 2-hop OPEN + CONNECTED_EXTENSIBLE)
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --hubs identity_role,media_artwork,mood_taxonomy,social_graph

# Query by touched file path substring (1-hop close + 2-hop distant hub relatives)
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --file explore_social_post_card.dart

# Inspect a specific phase memory card & connections
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --phase P69
```
