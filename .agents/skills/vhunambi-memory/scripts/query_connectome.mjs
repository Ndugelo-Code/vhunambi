#!/usr/bin/env node
/**
 * Vhunambi Codebase Brain — Zero-Token Connectome Query CLI (Node 24 ESM)
 *
 * Flags:
 *   --hubs <comma,list>                    Query OPEN + CONNECTED_EXTENSIBLE endpoints by Concept Hubs
 *   --file <substring>                     Query 1-hop close endpoints & 2-hop distant hub relatives for a file
 *   --status OPEN|CONNECTED_EXTENSIBLE|SEALED
 *   --open                                 Shortcut for --status OPEN
 *   --phase <P69>                          Print full phase memory card + incoming/outgoing connections
 *   --include-sealed                       Include SEALED endpoints in --hubs / --file output
 *   --json                                 Emit machine-readable JSON output
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, '../../../..');
const GRAPH_PATH = path.join(REPO_ROOT, 'docs', 'memory', 'CONNECTOME_GRAPH.json');

function normalizeHub(h) {
  return String(h || '').trim().toLowerCase().replace(/^#/, '');
}

function parseArgs(argv) {
  const args = {
    hubs: [],
    file: null,
    status: null,
    phase: null,
    includeSealed: false,
    json: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i];
    if (tok === '--hubs' && argv[i + 1]) {
      args.hubs = argv[++i].split(',').map(normalizeHub).filter(Boolean);
    } else if (tok === '--file' && argv[i + 1]) {
      args.file = argv[++i].trim();
    } else if (tok === '--status' && argv[i + 1]) {
      args.status = argv[++i].trim().toUpperCase();
    } else if (tok === '--open') {
      args.status = 'OPEN';
    } else if (tok === '--phase' && argv[i + 1]) {
      args.phase = argv[++i].trim().toUpperCase();
    } else if (tok === '--include-sealed') {
      args.includeSealed = true;
    } else if (tok === '--json') {
      args.json = true;
    } else if (tok === '--help' || tok === '-h') {
      args.help = true;
    }
  }
  return args;
}

function printEndpoint(ep, indent = '  ') {
  console.log(`${indent}[${ep.state}] ${ep.id} (${ep.kind} · origin: ${ep.origin_phase})`);
  console.log(`${indent}  Hubs: ${ep.hubs.map((h) => `#${h}`).join(', ')}`);
  if (ep.code_anchor) console.log(`${indent}  Code: ${ep.code_anchor}`);
  if (ep.spec_anchor) console.log(`${indent}  Spec: ${ep.spec_anchor}`);
  if (ep.summary) console.log(`${indent}  Summary: ${ep.summary}`);
  console.log(
    `${indent}  Consumers (${ep.consumers.length}): ${ep.consumers.length ? ep.consumers.join(', ') : 'NONE'}`,
  );
  if (ep.open_opportunities) {
    console.log(`${indent}  Opportunity: ${ep.open_opportunities}`);
  }
}

function main() {
  const started = performance.now();
  const args = parseArgs(process.argv.slice(2));

  if (
    args.help ||
    (!args.hubs.length && !args.file && !args.status && !args.phase)
  ) {
    console.log(
      'Usage: node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs [--open] [--status OPEN|CONNECTED_EXTENSIBLE|SEALED] [--hubs h1,h2] [--file path_substr] [--phase P69] [--include-sealed] [--json]',
    );
    process.exit(0);
  }

  if (!fs.existsSync(GRAPH_PATH)) {
    console.error(
      `Missing ${GRAPH_PATH}. Run consolidate_memory.mjs first.`,
    );
    process.exit(1);
  }

  const graph = JSON.parse(fs.readFileSync(GRAPH_PATH, 'utf8'));
  const allEndpoints = Object.values(graph.endpoints || {});
  const phasesById = Object.fromEntries(
    (graph.phases || []).map((p) => [p.phase_id.toUpperCase(), p]),
  );

  // Mode 1: --phase <PXX>
  if (args.phase) {
    const ph = phasesById[args.phase];
    if (!ph) {
      console.error(`Phase "${args.phase}" not found in CONNECTOME_GRAPH.json.`);
      process.exit(1);
    }
    const defined = ph.endpoints_defined.map((id) => graph.endpoints[id]).filter(Boolean);
    const consumed = ph.consumes.map((id) => graph.endpoints[id]).filter(Boolean);
    const incomingPhases = graph.phases
      .filter((other) =>
        other.consumes.some((cid) => ph.endpoints_defined.includes(cid)),
      )
      .map((other) => other.phase_id);

    const payload = {
      mode: 'phase',
      phase: ph,
      defined_endpoints: defined,
      consumed_endpoints: consumed,
      incoming_consumer_phases: incomingPhases,
      elapsed_ms: Number((performance.now() - started).toFixed(2)),
    };
    if (args.json) {
      console.log(JSON.stringify(payload, null, 2));
      return;
    }

    console.log(`=== PHASE CARD: ${ph.phase_id} — ${ph.title} (${ph.status}) ===`);
    console.log(`Memory File: ${ph.memory_file}`);
    console.log(`Hubs: ${ph.concept_hubs.map((h) => `#${h}`).join(', ')}`);
    console.log(`Predecessors: ${ph.predecessor_keys.join(', ') || 'None'}`);
    console.log(`Downstream Phases Consuming ${ph.phase_id}: ${incomingPhases.join(', ') || 'None yet'}`);
    console.log('\nDefined Endpoints:');
    for (const ep of defined) printEndpoint(ep);
    console.log('\nConsumed Endpoints:');
    if (consumed.length === 0) console.log('  None');
    for (const ep of consumed) {
      console.log(`  <- ${ep.id} (${ep.origin_phase}) [${ep.code_anchor || ep.spec_anchor}]`);
    }
    if (ph.edges.length > 0) {
      console.log('\nDirect 1-Hop Edges:');
      for (const e of ph.edges) {
        console.log(`  ${e.from} --[${e.relation}]--> ${e.to}${e.note ? ` (${e.note})` : ''}`);
      }
    }
    console.log('\nBreakthroughs:');
    for (const b of ph.breakthroughs) console.log(`  * ${b}`);
    console.log('\nGotchas / Dead Ends:');
    for (const g of ph.gotchas) console.log(`  ! ${g}`);
    console.log(`\nQuery completed in ${payload.elapsed_ms} ms`);
    return;
  }

  // Mode 2: --file <substring>
  if (args.file) {
    const needle = args.file.toLowerCase().replace(/\\/g, '/');
    const closeEndpoints = allEndpoints.filter((ep) => {
      const code = (ep.code_anchor || '').toLowerCase();
      const spec = (ep.spec_anchor || '').toLowerCase();
      const cons = ep.consumers.join(' ').toLowerCase();
      return code.includes(needle) || spec.includes(needle) || cons.includes(needle);
    });

    const closeEdges = [];
    for (const ph of graph.phases) {
      for (const e of ph.edges) {
        if (
          e.from.toLowerCase().includes(needle) ||
          e.to.toLowerCase().includes(needle)
        ) {
          closeEdges.push({ phase: ph.phase_id, ...e });
          if (graph.endpoints[e.to] && !closeEndpoints.some((x) => x.id === e.to)) {
            closeEndpoints.push(graph.endpoints[e.to]);
          }
        }
      }
    }

    const relatedHubs = new Set();
    for (const ep of closeEndpoints) {
      for (const h of ep.hubs) relatedHubs.add(h);
    }

    const closeIds = new Set(closeEndpoints.map((e) => e.id));
    const distantRelatives = allEndpoints.filter(
      (ep) =>
        !closeIds.has(ep.id) &&
        (args.includeSealed || ep.state !== 'SEALED') &&
        ep.hubs.some((h) => relatedHubs.has(h)),
    );

    const payload = {
      mode: 'file',
      query: args.file,
      close_endpoints: closeEndpoints,
      close_edges: closeEdges,
      related_hubs: [...relatedHubs],
      distant_hub_relatives: distantRelatives,
      elapsed_ms: Number((performance.now() - started).toFixed(2)),
    };
    if (args.json) {
      console.log(JSON.stringify(payload, null, 2));
      return;
    }

    console.log(`=== CONNECTOME FILE QUERY: "${args.file}" (${payload.elapsed_ms} ms) ===`);
    console.log(`\n1-Hop Close Endpoints (${closeEndpoints.length}):`);
    for (const ep of closeEndpoints) printEndpoint(ep);
    if (closeEdges.length > 0) {
      console.log(`\n1-Hop Structural Edges (${closeEdges.length}):`);
      for (const e of closeEdges) {
        console.log(`  [${e.phase}] ${e.from} --[${e.relation}]--> ${e.to}${e.note ? ` (${e.note})` : ''}`);
      }
    }
    console.log(
      `\n2-Hop Distant Relatives via Hubs [${[...relatedHubs].map((h) => `#${h}`).join(', ')}] (${distantRelatives.length}):`,
    );
    for (const ep of distantRelatives) printEndpoint(ep);
    return;
  }

  // Mode 3: --hubs and/or --status
  let matched = allEndpoints;
  if (args.status) {
    matched = matched.filter((ep) => ep.state === args.status);
  } else if (!args.includeSealed) {
    matched = matched.filter((ep) => ep.state !== 'SEALED');
  }

  if (args.hubs.length > 0) {
    const hubSet = new Set(args.hubs);
    matched = matched.filter((ep) => ep.hubs.some((h) => hubSet.has(h)));
  }

  // Sort OPEN first, then newest origin phase first
  matched.sort((a, b) => {
    if (a.state !== b.state) {
      if (a.state === 'OPEN') return -1;
      if (b.state === 'OPEN') return 1;
    }
    return b.origin_order - a.origin_order;
  });

  const relatedPhaseIds = [...new Set(matched.map((e) => e.origin_phase))];
  const relatedPhases = relatedPhaseIds
    .map((pid) => phasesById[pid.toUpperCase()])
    .filter(Boolean);

  const payload = {
    mode: args.hubs.length ? 'hubs' : 'status',
    hubs: args.hubs,
    status: args.status,
    count: matched.length,
    endpoints: matched,
    related_phase_notes: relatedPhases.map((p) => ({
      phase_id: p.phase_id,
      memory_file: p.memory_file,
      breakthroughs: p.breakthroughs,
      gotchas: p.gotchas,
    })),
    elapsed_ms: Number((performance.now() - started).toFixed(2)),
  };

  if (args.json) {
    console.log(JSON.stringify(payload, null, 2));
    return;
  }

  const headerParts = [];
  if (args.hubs.length) headerParts.push(`hubs=[${args.hubs.map((h) => `#${h}`).join(', ')}]`);
  if (args.status) headerParts.push(`status=${args.status}`);
  console.log(
    `=== CONNECTOME QUERY (${headerParts.join(' · ')}) — ${matched.length} endpoints (${payload.elapsed_ms} ms) ===`,
  );

  const openList = matched.filter((e) => e.state === 'OPEN');
  const extList = matched.filter((e) => e.state === 'CONNECTED_EXTENSIBLE');
  const sealedList = matched.filter((e) => e.state === 'SEALED');

  if (openList.length > 0) {
    console.log(`\n--- OPEN Endpoints (${openList.length}) ---`);
    for (const ep of openList) printEndpoint(ep);
  }
  if (extList.length > 0) {
    console.log(`\n--- CONNECTED_EXTENSIBLE Endpoints (${extList.length}) ---`);
    for (const ep of extList) printEndpoint(ep);
  }
  if (sealedList.length > 0) {
    console.log(`\n--- SEALED Endpoints (${sealedList.length}) ---`);
    for (const ep of sealedList) printEndpoint(ep);
  }

  if (args.hubs.length > 0 && relatedPhases.length > 0) {
    console.log('\n--- Related Phase Breakthroughs & Gotchas ---');
    for (const p of relatedPhases) {
      console.log(`  [${p.phase_id}] ${p.title} (${p.memory_file})`);
      for (const b of p.breakthroughs.slice(0, 2)) {
        console.log(`    * ${b}`);
      }
      for (const g of p.gotchas.slice(0, 2)) {
        console.log(`    ! ${g}`);
      }
    }
  }
}

main();
