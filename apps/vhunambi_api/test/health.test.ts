import assert from 'node:assert';
import { app } from '../src/server.js';
import {
  completeJob,
  countActiveJobs,
  createJob,
} from '../src/modules/jobs/job_store.js';

/** Shape returned by `GET /health` and `GET /v1/health`. */
interface HealthPayload {
  status: string;
  service: string;
  uptimeSeconds: number;
  memoryMb: number;
  environment: string;
  activeJobs: number;
  timestamp: string;
}

const EXPECTED_KEYS = [
  'activeJobs',
  'environment',
  'memoryMb',
  'service',
  'status',
  'timestamp',
  'uptimeSeconds',
];

async function fetchHealth(path: string): Promise<{
  status: number;
  body: HealthPayload;
}> {
  // `app.request()` is Hono's documented testing entry point (accepts a path
  // string); `app.fetch()` would require a fully-formed Request object.
  const res = await app.request(path);
  const body = (await res.json()) as HealthPayload;
  return { status: res.status, body };
}

function assertHealthSchema(path: string, body: HealthPayload): void {
  // Exact key set — the schema IS the contract.
  assert.deepStrictEqual(
    Object.keys(body).sort(),
    EXPECTED_KEYS,
    `${path} must expose exactly the documented health fields`,
  );

  assert.strictEqual(body.status, 'ok', `${path} status must be 'ok'`);
  assert.strictEqual(
    body.service,
    'vhunambi_api',
    `${path} service must be 'vhunambi_api'`,
  );

  assert.ok(
    Number.isInteger(body.uptimeSeconds) && body.uptimeSeconds >= 0,
    `${path} uptimeSeconds must be a non-negative integer`,
  );
  assert.ok(
    Number.isFinite(body.memoryMb) && body.memoryMb > 0,
    `${path} memoryMb must be a positive number`,
  );
  assert.ok(
    typeof body.environment === 'string' && body.environment.length > 0,
    `${path} environment must be a non-empty string`,
  );
  assert.ok(
    Number.isInteger(body.activeJobs) && body.activeJobs >= 0,
    `${path} activeJobs must be a non-negative integer`,
  );
  assert.ok(
    !Number.isNaN(Date.parse(body.timestamp)),
    `${path} timestamp must be an ISO-8601 date string`,
  );
}

async function runTests() {
  console.log('🧪 Running Vhunambi API Health Endpoint Tests...');

  // Test 1: GET /health → 200 + schema
  console.log('  1. Testing GET /health...');
  const canonical = await fetchHealth('/health');
  assert.strictEqual(canonical.status, 200, '/health must return 200');
  assertHealthSchema('/health', canonical.body);
  console.log('     ✅ GET /health passed');

  // Test 2: GET /v1/health → 200 + identical schema (versioned alias)
  console.log('  2. Testing GET /v1/health...');
  const versioned = await fetchHealth('/v1/health');
  assert.strictEqual(versioned.status, 200, '/v1/health must return 200');
  assertHealthSchema('/v1/health', versioned.body);
  assert.strictEqual(
    versioned.body.service,
    canonical.body.service,
    'Both aliases must report the same service id',
  );
  console.log('     ✅ GET /v1/health passed');

  // Test 3: activeJobs metric reacts to the job store lifecycle
  console.log('  3. Testing activeJobs wiring...');
  const baseline = countActiveJobs();

  createJob({
    generationId: 'gen_health_probe',
    trackTitle: 'Health Probe',
    genre: 'Amapiano',
    language: 've',
  });
  const during = await fetchHealth('/health');
  assert.strictEqual(
    during.body.activeJobs,
    baseline + 1,
    'Queued job must count as active',
  );

  completeJob('gen_health_probe', {
    masterMp3Url: 'https://cdn.vhunambi.com/audio/gen_health_probe_master.mp3',
  });
  const after = await fetchHealth('/health');
  assert.strictEqual(
    after.body.activeJobs,
    baseline,
    'Completed job must leave the active count',
  );
  console.log('     ✅ activeJobs wiring passed');

  console.log('\n🎉 ALL TESTS PASSED! Health endpoints verified.');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});