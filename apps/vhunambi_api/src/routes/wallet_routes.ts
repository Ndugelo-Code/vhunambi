import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const walletRoutes = new Hono();

// GET /api/wallet/:creatorId (REQ-P45-WAL-01)
walletRoutes.get('/:creatorId', (c) => {
  const creatorId = c.req.param('creatorId');
  const wallet = vhunambiDb.getWallet(creatorId);
  return c.json(wallet);
});

// POST /api/wallet/topup (REQ-P45-WAL-02)
walletRoutes.post('/topup', async (c) => {
  const body = await c.req.json();
  const creatorId = body.creatorId || 'creator_cern';
  const amountZar = Number(body.amountZar) || 0;
  const amountCoins = Number(body.amountCoins) || 0;

  const wallet = vhunambiDb.topupWallet(creatorId, amountZar, amountCoins);
  return c.json({ success: true, wallet });
});

// POST /api/wallet/payout (REQ-P45-WAL-03..05)
walletRoutes.post('/payout', async (c) => {
  const body = await c.req.json();
  const creatorId = body.creatorId || 'creator_cern';
  const amountZar = Number(body.amountZar) || 0;
  const bankName = body.bankName;
  const accountNumber = body.accountNumber;
  const branchCode = body.branchCode;

  const result = vhunambiDb.requestPayout({
    creatorId,
    amountZar,
    bankName,
    accountNumber,
    branchCode,
  });

  if (!result.success) {
    return c.json({ success: false, error: result.error }, 400);
  }

  return c.json(result);
});

