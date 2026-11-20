#!/usr/bin/env node
/**
 * Vhunambi Codebase Brain — Sleep & Dream Consolidator (Zero Dependencies, Node 24 ESM)
 *
 * Scans:
 *   - docs/phases/<phase_dir>/memory.md
 *   - docs/memory/sprints/*.md
 *
 * Outputs:
 *   - docs/memory/CONNECTOME_GRAPH.json
 *   - docs/memory/CORTEX_INDEX.md (compact < 6 KB briefing)
 *   - Console DREAM Pass Synergy & Ripple Report
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '../../../..');

const PHASES_DIR = path.join(REPO_ROOT, 'docs', 'phases');
const SPRINTS_DIR = path.join(REPO_ROOT, 'docs', 'memory', 'sprints');
const MEMORY_DIR = path.join(REPO_ROOT, 'docs', 'memory');
const GRAPH_PATH = path.join(MEMORY_DIR, 'CONNECTOME_GRAPH.json');
const CORTEX_PATH = path.join(MEMORY_DIR, 'CORTEX_INDEX.md');

const CANONICAL_HUBS = [
  'identity_role',
  'media_artwork',
  'quota_economy',
  'audio_transport',
  'mood_taxonomy',
  'social_graph',
  'notifications_bus',
  'sync_outbox',
  'ui_surface_std',
  'ai_synthesis_gpu',
];

const VALID_STATES = new Set(['OPEN', 'CONNECTED_EXTENSIBLE', 'SEALED']);
const VALID_STATUSES = new Set(['draft', 'in_progress', 'completed']);

function normalizeHub(hub) {
  return String(hub || '')
    .trim()
    .toLowerCase()
    .replace(/^#/, '');
}

function normalizePath(p) {
  return String(p || '').trim().replace(/\\/g, '/');
}

function toRepoRelative(absPath) {
  return path.relative(REPO_ROOT, absPath).replace(/\\/g, '/');
}

/**
 * Computes a numeric sort rank for phase IDs like P00_P63, P64, P68.5, P69.
 * Range IDs (P00_P63) sort by their upper bound (63).
 */
function parsePhaseOrder(phaseId) {
  const str = String(phaseId || '').trim().toUpperCase();
  const matches = [...str.matchAll(/P?(\d+(?:\.\d+)?)/g)].map((m) => Number(m[1]));
  if (matches.length === 0) return -1;
  return matches[matches.length - 1];
}

function discoverMemoryFiles() {
  const files = [];

  if (fs.existsSync(PHASES_DIR)) {
    for (const entry of fs.readdirSync(PHASES_DIR, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const candidate = path.join(PHASES_DIR, entry.name, 'memory.md');
      if (fs.existsSync(candidate)) {
        files.push(candidate);
      }
    }
  }

  if (fs.existsSync(SPRINTS_DIR)) {
    for (const entry of fs.readdirSync(SPRINTS_DIR, { withFileTypes: true })) {
      if (entry.isFile() && entry.name.endsWith('.md')) {
        files.push(path.join(SPRINTS_DIR, entry.name));
      }
    }
  }

  return files.sort();
}

function extractMemoryBlock(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const match = raw.match(/```json\s+vhunambi-memory\s*\r?\n([\s\S]*?)\r?\n```/);
  if (!match) {
    throw new Error(
      `Missing fenced \`\`\`json vhunambi-memory\`\`\` block in ${toRepoRelative(filePath)}`,
    );
  }
  let parsed;
  try {
    parsed = JSON.parse(match[1]);
  } catch (err) {
    throw new Error(
      `Invalid JSON in ${toRepoRelative(filePath)}: ${err.message}`,
    );
  }

  const rel = toRepoRelative(filePath);
  for (const field of ['phase_id', 'memory_key', 'title', 'status']) {
    if (!parsed[field] || typeof parsed[field] !== 'string') {
      throw new Error(`Missing required string field "${field}" in ${rel}`);
    }
  }
  if (!VALID_STATUSES.has(parsed.status)) {
    throw new Error(
      `Invalid status "${parsed.status}" in ${rel} (expected draft | in_progress | completed)`,
    );
  }

  const conceptHubs = (parsed.concept_hubs || []).map(normalizeHub).filter(Boolean);
  for (const h of conceptHubs) {
    if (!CANONICAL_HUBS.includes(h)) {
      console.warn(`[WARN] Non-canonical hub "${h}" in ${rel}`);
    }
  }

  const endpoints = Array.isArray(parsed.endpoints) ? parsed.endpoints : [];
  for (const ep of endpoints) {
    if (!ep.id || !ep.state) {
      throw new Error(`Endpoint missing id/state in ${rel}`);
    }
    if (!VALID_STATES.has(ep.state)) {
      throw new Error(
        `Invalid endpoint state "${ep.state}" for ${ep.id} in ${rel}`,
      );
    }
  }

  return {
    phase_id: parsed.phase_id.trim(),
    phase_order: parsePhaseOrder(parsed.phase_id),
    memory_key: parsed.memory_key.trim(),
    title: parsed.title.trim(),
    status: parsed.status.trim(),
    completed_at: parsed.completed_at ?? null,
    memory_file: rel,
    predecessor_keys: Array.isArray(parsed.predecessor_keys)
      ? parsed.predecessor_keys
      : [],
    concept_hubs: [...new Set(conceptHubs)],
    consumes: Array.isArray(parsed.consumes) ? parsed.consumes : [],
    endpoints,
    edges: Array.isArray(parsed.edges) ? parsed.edges : [],
    breakthroughs: Array.isArray(parsed.breakthroughs) ? parsed.breakthroughs : [],
    gotchas: Array.isArray(parsed.gotchas) ? parsed.gotchas : [],
  };
}

function buildGraph(memoryRecords) {
  const sortedPhases = [...memoryRecords].sort((a, b) => {
    if (a.phase_order !== b.phase_order) return a.phase_order - b.phase_order;
    return a.phase_id.localeCompare(b.phase_id);
  });

  const endpointsMap = {};
  const phasesOut = [];

  // Pass 1: Register all declared endpoints
  for (const rec of sortedPhases) {
    const definedIds = [];
    for (const ep of rec.endpoints) {
      const normalizedHubs = [...new Set((ep.hubs || []).map(normalizeHub).filter(Boolean))];
      const consumers = [...new Set(Array.isArray(ep.consumers) ? ep.consumers : [])];
      const existing = endpointsMap[ep.id];

      if (existing) {
        // Merge metadata if later phase re-declares/extends an endpoint
        existing.hubs = [...new Set([...existing.hubs, ...normalizedHubs])];
        existing.consumers = [...new Set([...existing.consumers, ...consumers])];
        if (ep.open_opportunities) existing.open_opportunities = ep.open_opportunities;
        if (ep.spec_anchor) existing.spec_anchor = ep.spec_anchor;
        if (ep.code_anchor) existing.code_anchor = normalizePath(ep.code_anchor);
        if (ep.state === 'SEALED') existing.state = 'SEALED';
        else if (existing.state === 'OPEN' && ep.state === 'CONNECTED_EXTENSIBLE') {
          existing.state = 'CONNECTED_EXTENSIBLE';
        }
      } else {
        endpointsMap[ep.id] = {
          id: ep.id,
          kind: ep.kind || 'primitive',
          state: ep.state,
          origin_phase: rec.phase_id,
          origin_order: rec.phase_order,
          memory_file: rec.memory_file,
          hubs: normalizedHubs,
          spec_anchor: ep.spec_anchor ? normalizePath(ep.spec_anchor) : null,
          code_anchor: ep.code_anchor ? normalizePath(ep.code_anchor) : null,
          summary: ep.summary || null,
          consumers,
          consumed_by_phases: [],
          open_opportunities: ep.open_opportunities || null,
        };
      }
      definedIds.push(ep.id);
    }

    phasesOut.push({
      phase_id: rec.phase_id,
      phase_order: rec.phase_order,
      memory_key: rec.memory_key,
      title: rec.title,
      status: rec.status,
      completed_at: rec.completed_at,
      memory_file: rec.memory_file,
      predecessor_keys: rec.predecessor_keys,
      concept_hubs: rec.concept_hubs,
      endpoints_defined: definedIds,
      consumes: rec.consumes,
      edges: rec.edges.map((e) => ({
        from: normalizePath(e.from),
        relation: String(e.relation || 'RELATES_TO').toUpperCase(),
        to: normalizePath(e.to),
        note: e.note || null,
      })),
      breakthroughs: rec.breakthroughs,
      gotchas: rec.gotchas,
    });
  }

  // Pass 2: Merge cross-phase consumes[] & auto-promote OPEN -> CONNECTED_EXTENSIBLE
  const autoPromoted = [];
  for (const ph of phasesOut) {
    for (const targetId of ph.consumes) {
      const ep = endpointsMap[targetId];
      if (!ep) {
        console.warn(
          `[WARN] Phase ${ph.phase_id} lists unknown consumed endpoint "${targetId}"`,
        );
        continue;
      }
      const consumerLabel = `${ph.phase_id}:${ph.title}`;
      if (!ep.consumed_by_phases.includes(ph.phase_id)) {
        ep.consumed_by_phases.push(ph.phase_id);
      }
      if (!ep.consumers.some((c) => c.startsWith(`${ph.phase_id}:`))) {
        ep.consumers.push(consumerLabel);
      }
      if (ph.status === 'completed' && ep.state === 'OPEN') {
        ep.state = 'CONNECTED_EXTENSIBLE';
        autoPromoted.push({ endpointId: ep.id, claimedBy: ph.phase_id });
      }
    }
  }

  // Pass 3: Build hub_index & file_index
  const hubIndex = {};
  for (const h of CANONICAL_HUBS) {
    hubIndex[h] = { endpoints: [], phases: [] };
  }
  for (const ph of phasesOut) {
    for (const h of ph.concept_hubs) {
      if (!hubIndex[h]) hubIndex[h] = { endpoints: [], phases: [] };
      if (!hubIndex[h].phases.includes(ph.phase_id)) {
        hubIndex[h].phases.push(ph.phase_id);
      }
    }
  }

  const fileIndex = {};
  for (const ep of Object.values(endpointsMap)) {
    for (const h of ep.hubs) {
      if (!hubIndex[h]) hubIndex[h] = { endpoints: [], phases: [] };
      if (!hubIndex[h].endpoints.includes(ep.id)) {
        hubIndex[h].endpoints.push(ep.id);
      }
    }
    if (ep.code_anchor) {
      const cleanAnchor = ep.code_anchor.split('#')[0];
      if (!fileIndex[cleanAnchor]) fileIndex[cleanAnchor] = [];
      if (!fileIndex[cleanAnchor].includes(ep.id)) {
        fileIndex[cleanAnchor].push(ep.id);
      }
    }
  }

  const completedPhases = phasesOut.filter((p) => p.status === 'completed');
  const latestCompleted =
    completedPhases.length > 0
      ? completedPhases[completedPhases.length - 1]
      : null;

  const allEndpoints = Object.values(endpointsMap);
  const stats = {
    total_phases: phasesOut.length,
    completed_phases: completedPhases.length,
    total_endpoints: allEndpoints.length,
    open_count: allEndpoints.filter((e) => e.state === 'OPEN').length,
    connected_extensible_count: allEndpoints.filter(
      (e) => e.state === 'CONNECTED_EXTENSIBLE',
    ).length,
    sealed_count: allEndpoints.filter((e) => e.state === 'SEALED').length,
  };

  return {
    graph: {
      schema_version: '1.0.0',
      generated_at: new Date().toISOString(),
      latest_completed_phase: latestCompleted ? latestCompleted.phase_id : null,
      latest_completed_order: latestCompleted ? latestCompleted.phase_order : 0,
      stats,
      phases: phasesOut,
      endpoints: endpointsMap,
      hub_index: hubIndex,
      file_index: fileIndex,
    },
    autoPromoted,
  };
}

function shortAnchor(anchor) {
  if (!anchor) return '—';
  const clean = anchor.replace(/^apps\/vhunambi_client\/lib\//, 'client/')
    .replace(/^apps\/vhunambi_api\/src\//, 'api/')
    .replace(/^tools\/zr-studio-gpu\//, 'gpu/');
  return `\`${clean}\``;
}

function generateCortexIndex(graph) {
  const completed = graph.phases.filter((p) => p.status === 'completed');
  const recent3 = completed.slice(-3).reverse();
  const openEndpoints = Object.values(graph.endpoints).filter(
    (e) => e.state === 'OPEN',
  );
  const extensibleEndpoints = Object.values(graph.endpoints).filter(
    (e) => e.state === 'CONNECTED_EXTENSIBLE',
  );

  const lines = [];
  lines.push('# Vhunambi Cortex Index (`CORTEX_INDEX.md`)');
  lines.push('');
  lines.push(
    `> **Auto-generated by \`consolidate_memory.mjs\`** · Latest Completed: **\`${graph.latest_completed_phase || 'NONE'}\`** · Phases Indexed: \`${graph.stats.total_phases}\` · Endpoints: \`${graph.stats.open_count} OPEN\` · \`${graph.stats.connected_extensible_count} CONNECTED_EXTENSIBLE\` · \`${graph.stats.sealed_count} SEALED\``,
  );
  lines.push('');

  // 1. Current Repo Pulse (Latest 3 Completed Phases)
  lines.push('## 1. Current Repo Pulse (Latest 3 Completed Phases)');
  lines.push('');
  for (const ph of recent3) {
    const bt = ph.breakthroughs[0] || 'See phase memory file.';
    const gotcha = ph.gotchas[0] ? ` *Gotcha:* ${ph.gotchas[0]}` : '';
    lines.push(
      `- **\`${ph.phase_id}\` — ${ph.title}** (\`${ph.memory_file}\`): ${bt}${gotcha}`,
    );
  }
  lines.push('');

  // 2. Active OPEN Endpoints Queue
  lines.push('## 2. Active `OPEN` Endpoints Queue (Zero Direct Client Consumers)');
  lines.push('');
  lines.push('| Endpoint ID | Origin | Hubs | Code Anchor | Opportunity |');
  lines.push('| :--- | :---: | :--- | :--- | :--- |');
  for (const ep of openEndpoints) {
    const hubs = ep.hubs.map((h) => `\`#${h}\``).join(', ');
    const rawOpp = ep.open_opportunities || ep.summary || 'Ready to wire';
    const opp = rawOpp.length > 68 ? `${rawOpp.slice(0, 65)}...` : rawOpp;
    lines.push(
      `| \`${ep.id}\` | \`${ep.origin_phase}\` | ${hubs} | ${shortAnchor(ep.code_anchor)} | ${opp} |`,
    );
  }
  lines.push('');

  // 3. Core CONNECTED_EXTENSIBLE Shared Primitives (compact top 12 by newest phase)
  const topExtensible = [...extensibleEndpoints]
    .sort((a, b) => b.origin_order - a.origin_order)
    .slice(0, 12);
  lines.push(
    `## 3. Core \`CONNECTED_EXTENSIBLE\` Shared Primitives (Top ${topExtensible.length}/${extensibleEndpoints.length})`,
  );
  lines.push('');
  lines.push('| Endpoint ID | Origin | Cons. | Hubs | Code Anchor |');
  lines.push('| :--- | :---: | :---: | :--- | :--- |');
  for (const ep of topExtensible) {
    const hubs = ep.hubs.map((h) => `\`#${h}\``).join(', ');
    lines.push(
      `| \`${ep.id}\` | \`${ep.origin_phase}\` | ${ep.consumers.length} | ${hubs} | ${shortAnchor(ep.code_anchor)} |`,
    );
  }
  lines.push('');

  // 4. Zero-Token Query Cheat Sheet
  lines.push('## 4. Zero-Token Connectome Query Cheat Sheet');
  lines.push('');
  lines.push('```powershell');
  lines.push('node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open');
  lines.push('node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --hubs identity_role,media_artwork,mood_taxonomy,social_graph');
  lines.push('node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --file track_detail_view.dart');
  lines.push('node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --phase P69');
  lines.push('```');
  lines.push('');

  return lines.join('\n');
}

function runDreamPass(graph, autoPromoted) {
  const latestOrder = graph.latest_completed_order || 0;
  const latestPhase = graph.phases.find(
    (p) => p.phase_id === graph.latest_completed_phase,
  );
  const latestHubs = new Set(latestPhase ? latestPhase.concept_hubs : []);

  const staleOpen = Object.values(graph.endpoints).filter(
    (e) => e.state === 'OPEN' && latestOrder - e.origin_order >= 2,
  );

  const hubSynergies = Object.values(graph.endpoints).filter(
    (e) =>
      e.state === 'CONNECTED_EXTENSIBLE' &&
      e.origin_phase !== graph.latest_completed_phase &&
      e.open_opportunities &&
      e.hubs.some((h) => latestHubs.has(h)),
  );

  console.log('\n=== VHUNAMBI MEMORY CONSOLIDATION & DREAM RIPPLE REPORT ===');
  console.log(
    `Consolidated ${graph.stats.total_phases} phases -> ${graph.stats.total_endpoints} endpoints (${graph.stats.open_count} OPEN, ${graph.stats.connected_extensible_count} CONNECTED_EXTENSIBLE, ${graph.stats.sealed_count} SEALED).`,
  );
  if (autoPromoted.length > 0) {
    console.log('Auto-Promoted OPEN -> CONNECTED_EXTENSIBLE:');
    for (const p of autoPromoted) {
      console.log(`  * ${p.endpointId} (claimed by ${p.claimedBy})`);
    }
  }

  console.log(
    `\n[DREAM 1] Stale OPEN Endpoints (>= 2 phases behind ${graph.latest_completed_phase || 'HEAD'}): ${staleOpen.length}`,
  );
  for (const ep of staleOpen.slice(0, 6)) {
    console.log(
      `  - ${ep.id} (${ep.origin_phase}, hubs: ${ep.hubs.join(',')}): ${ep.open_opportunities || ep.code_anchor}`,
    );
  }
  if (staleOpen.length > 6) {
    console.log(`  ... +${staleOpen.length - 6} more (run query_connectome.mjs --open)`);
  }

  console.log(
    `\n[DREAM 2] Distant CONNECTED_EXTENSIBLE Synergies Sharing ${graph.latest_completed_phase || 'Latest'} Hubs (${[...latestHubs].join(', ')}): ${hubSynergies.length}`,
  );
  for (const ep of hubSynergies.slice(0, 5)) {
    console.log(
      `  - ${ep.id} (${ep.origin_phase}): ${ep.open_opportunities}`,
    );
  }
  console.log('');
}

function main() {
  fs.mkdirSync(MEMORY_DIR, { recursive: true });
  const memoryFiles = discoverMemoryFiles();
  if (memoryFiles.length === 0) {
    console.error('No memory.md files found under docs/phases/*/memory.md or docs/memory/sprints/*.md');
    process.exit(1);
  }

  const records = memoryFiles.map(extractMemoryBlock);
  const { graph, autoPromoted } = buildGraph(records);

  fs.writeFileSync(GRAPH_PATH, `${JSON.stringify(graph, null, 2)}\n`, 'utf8');
  const cortexMd = generateCortexIndex(graph);
  fs.writeFileSync(CORTEX_PATH, cortexMd, 'utf8');

  const cortexBytes = Buffer.byteLength(cortexMd, 'utf8');
  console.log(`Wrote ${toRepoRelative(GRAPH_PATH)} (${Buffer.byteLength(JSON.stringify(graph), 'utf8')} bytes compact)`);
  console.log(`Wrote ${toRepoRelative(CORTEX_PATH)} (${cortexBytes} bytes)`);
  runDreamPass(graph, autoPromoted);
}

main();
