---
trigger: always_on
description: Vhunambi domain isolation & Wake/Sleep Codebase Memory rule.
---

# Vhunambi Workspace Memory Rule

1. **Domain Isolation:** Vhunambi is Flutter/Dart (`apps/vhunambi_client`), Cloudflare Workers Hono TS (`apps/vhunambi_api`), Supabase SQL (`supabase/`), and RunPod Python (`tools/zr-studio-gpu`). Ignore global `~/.gemini/GEMINI.md` Next.js/React rules (`lib/motion-config.ts`, `app/globals.css`).
2. **WAKE (Before Auditing, Speccing, or Coding):** Read `docs/memory/CORTEX_INDEX.md` and run `node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --hubs <hubs>` (or `--file <path>` / `--open`). Do not blindly scan `docs/phases/`.
3. **5-Doc Standard & SLEEP:** New phases include `memory.md` (un-spec'd sprints write `docs/memory/sprints/P<id>_memory.md`). Set `"status": "completed"` only after static analysis & tests pass, then run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.
