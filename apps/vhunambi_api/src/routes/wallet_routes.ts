import { Hono } from 'hono';
import { extractWorkerEnv } from '../config/env.js';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  isStrictAuthEnforced,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const walletRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

walletRoutes.use('*', sovereignAuthMiddleware);

// GET /api/wallet/banks — Canonical South African bank metadata & payment rails
// NOTE: Registered before /:creatorId so 'banks' is never treated as a creatorId.
walletRoutes.get('/banks', (c) => {
  return c.json({
    success: true,
    banks: vhunambiDb.getSaBanks(),
    rails: [
      { id: 'capitec_pay', label: 'Capitec Pay', settlement: 'Instant (< 60s)' },
      { id: 'ozow', label: 'Ozow Instant EFT', settlement: 'Instant (< 60s)' },
      { id: 'payfast', label: 'PayFast Instant', settlement: 'Instant (< 60s)' },
      { id: 'eft', label: 'Standard SA EFT', settlement: '1-2 Business Days' },
    ],
  });
});

// GET /api/wallet/:creatorId (REQ-P45-WAL-01 + Phase 61 Tenant Guard)
walletRoutes.get('/:creatorId', (c) => {
  const creatorId = c.req.param('creatorId');
  const forbidden = assertTenantCreatorAccess(c, creatorId);
  if (forbidden) return forbidden;

  const wallet = vhunambiDb.getWallet(creatorId);
  return c.json(wallet);
});

// POST /api/wallet/topup (REQ-P45-WAL-02 + Phase 61 Tenant Guard + Phase 62 Strict Payment Guard)
walletRoutes.post('/topup', async (c) => {
  try {
    const body = await c.req.json();
    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const workerEnv = extractWorkerEnv(c);
    if (isStrictAuthEnforced(c) || workerEnv?.NODE_ENV === 'production') {
      const paymentSig = c.req.header('x-vhunambi-payment-signature') ?? '';
      if (!paymentSig.trim()) {
        return c.json(
          {
            error: 'PAYMENT_VERIFICATION_REQUIRED',
            message:
              'Direct unverified wallet top-ups are disabled in strict mode. Use POST /api/payments/payfast/checkout and /api/payments/payfast/itn.',
          },
          403,
        );
      }
    }

    const creatorId = resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern');
    const amountZar = Number(body.amountZar) || 0;
    const amountCoins = Number(body.amountCoins) || 0;

    const wallet = vhunambiDb.topupWallet(creatorId, amountZar, amountCoins);
    return c.json({ success: true, wallet });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Topup failed';
    return c.json({ error: message }, 400);
  }
});

// POST /api/wallet/payout (REQ-P45-WAL-03..05 + Phase 59 SA Payment Rails + Phase 61 Tenant Guard)
walletRoutes.post('/payout', async (c) => {
  const body = await c.req.json();
  const forbidden = assertTenantCreatorAccess(c, body.creatorId);
  if (forbidden) return forbidden;

  const creatorId = resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern');
  const amountZar = Number(body.amountZar) || 0;
  const bankName = body.bankName;
  const accountNumber = body.accountNumber;
  const branchCode = body.branchCode;
  const paymentRail = body.paymentRail || body.payoutMethod || 'eft';
  const accountHolder = body.accountHolder;

  const result = vhunambiDb.requestPayout({
    creatorId,
    amountZar,
    bankName,
    accountNumber,
    branchCode,
    paymentRail,
    accountHolder,
  });

  if (!result.success) {
    return c.json({ success: false, error: result.error }, 400);
  }

  return c.json(result);
});

