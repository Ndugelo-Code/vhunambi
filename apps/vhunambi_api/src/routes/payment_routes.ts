import { createHash, timingSafeEqual } from 'node:crypto';
import { Hono } from 'hono';
import { resolveRuntimeEnv } from '../config/env.js';
import {
  canonicalizeCreatorId,
  vhunambiDb,
} from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const paymentRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

// Apply JWT auth to user-facing checkout/status/sandbox endpoints, NEVER to server-to-server /payfast/itn callbacks
paymentRoutes.use('/payfast/checkout', sovereignAuthMiddleware);
paymentRoutes.use('/payfast/status/*', sovereignAuthMiddleware);
paymentRoutes.use('/payfast/sandbox-settle/*', sovereignAuthMiddleware);

export interface CoinPackDefinition {
  packId: string;
  label: string;
  amountZar: number;
  coinsGranted: number;
}

export const SOVEREIGN_COIN_PACKS: Record<string, CoinPackDefinition> = {
  pack_starter_500: {
    packId: 'pack_starter_500',
    label: 'Starter Crate (500 Vhunambi Coins)',
    amountZar: 55.0,
    coinsGranted: 500,
  },
  pack_producer_1500: {
    packId: 'pack_producer_1500',
    label: 'Producer Vault (1,500 Vhunambi Coins)',
    amountZar: 150.0,
    coinsGranted: 1500,
  },
  pack_mogul_5000: {
    packId: 'pack_mogul_5000',
    label: 'Studio Mogul (5,000 Vhunambi Coins)',
    amountZar: 450.0,
    coinsGranted: 5000,
  },
};

function payFastUrlEncode(value: string): string {
  return encodeURIComponent(value.trim())
    .replace(/%20/g, '+')
    .replace(/[!'()*]/g, (ch) => `%${ch.charCodeAt(0).toString(16).toUpperCase()}`);
}

/**
 * Computes canonical PayFast ordered MD5 signature over non-empty form fields
 * plus optional `passphrase`.
 */
export function computePayFastSignature(
  fields: Record<string, string>,
  passphrase?: string,
): string {
  const pairs: string[] = [];
  for (const [key, rawVal] of Object.entries(fields)) {
    if (key === 'signature') continue;
    if (rawVal !== undefined && rawVal !== null && String(rawVal).trim() !== '') {
      pairs.push(`${key}=${payFastUrlEncode(String(rawVal))}`);
    }
  }
  if (passphrase && passphrase.trim().length > 0) {
    pairs.push(`passphrase=${payFastUrlEncode(passphrase)}`);
  }
  const serialized = pairs.join('&');
  return createHash('md5').update(serialized, 'utf8').digest('hex');
}

export function verifyPayFastSignatureConstantTime(
  fields: Record<string, string>,
  receivedSignature: string,
  passphrase?: string,
): boolean {
  const expectedHex = computePayFastSignature(fields, passphrase);
  const expectedBuf = Buffer.from(expectedHex.toLowerCase(), 'utf8');
  const receivedBuf = Buffer.from(
    (receivedSignature ?? '').trim().toLowerCase(),
    'utf8',
  );
  if (expectedBuf.length !== receivedBuf.length) {
    return false;
  }
  return timingSafeEqual(expectedBuf, receivedBuf);
}

/**
 * POST /api/payments/payfast/checkout
 * Initiates a signed PayFast checkout session and records a pending row in `payment_topups`.
 */
paymentRoutes.post('/payfast/checkout', async (c) => {
  const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const authUser = c.get('authUser');
  if (authUser && typeof body.creatorId === 'string' && body.creatorId.trim()) {
    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;
  }
  const creatorId = canonicalizeCreatorId(
    resolveEffectiveCreatorId(
      c,
      typeof body.creatorId === 'string' ? body.creatorId : undefined,
      'creator_cern',
    ),
  );

  const packKey = typeof body.packId === 'string' ? body.packId : '';
  const pack: CoinPackDefinition = SOVEREIGN_COIN_PACKS[packKey] ?? {
    packId: packKey || 'pack_custom',
    label:
      typeof body.itemName === 'string' && body.itemName.trim()
        ? body.itemName.trim()
        : 'Vhunambi Sovereign Coin Top-Up',
    amountZar: Math.max(10, Number(body.amountZar ?? 150)),
    coinsGranted: Math.max(50, Math.round(Number(body.coinsGranted ?? 1500))),
  };

  const runtimeEnv = resolveRuntimeEnv(c);
  const checkoutId = `chk_pf_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const notifyUrl = `${runtimeEnv.WEBHOOK_BASE_URL.replace(/\/+$/, '')}/api/payments/payfast/itn`;

  const orderedFields: Record<string, string> = {
    merchant_id: runtimeEnv.PAYFAST_MERCHANT_ID,
    merchant_key: runtimeEnv.PAYFAST_MERCHANT_KEY,
    notify_url: notifyUrl,
    m_payment_id: checkoutId,
    amount: pack.amountZar.toFixed(2),
    item_name: pack.label,
    custom_str1: creatorId,
    custom_str2: pack.packId,
    custom_int1: String(pack.coinsGranted),
  };

  const signature = computePayFastSignature(
    orderedFields,
    runtimeEnv.PAYFAST_PASSPHRASE,
  );

  vhunambiDb.createPayFastCheckout({
    checkoutId,
    creatorId,
    packId: pack.packId,
    amountZar: pack.amountZar,
    coinsGranted: pack.coinsGranted,
    signatureMd5: signature,
  });

  const gatewayHost = runtimeEnv.PAYFAST_SANDBOX
    ? 'https://sandbox.payfast.co.za/eng/process'
    : 'https://www.payfast.co.za/eng/process';

  return c.json(
    {
      checkoutId,
      creatorId,
      packId: pack.packId,
      amountZar: pack.amountZar,
      coinsToCredit: pack.coinsGranted,
      paymentUrl: gatewayHost,
      formFields: {
        ...orderedFields,
        signature,
      },
      signature,
      status: 'pending',
    },
    201,
  );
});

/**
 * POST /api/payments/payfast/itn
 * Verifies PayFast Instant Transaction Notification (ITN) signature, amount, and idempotency.
 */
paymentRoutes.post('/payfast/itn', async (c) => {
  const contentType = c.req.header('content-type') ?? '';
  const payload: Record<string, string> = {};

  if (contentType.includes('application/json')) {
    const rawJson = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    for (const [k, v] of Object.entries(rawJson)) {
      payload[k] = String(v ?? '');
    }
  } else {
    const text = await c.req.text();
    const params = new URLSearchParams(text);
    params.forEach((v, k) => {
      payload[k] = v;
    });
  }

  const runtimeEnv = resolveRuntimeEnv(c);
  const receivedSig = payload.signature ?? '';
  const { signature: _ignored, ...fieldsWithoutSig } = payload;

  if (
    !verifyPayFastSignatureConstantTime(
      fieldsWithoutSig,
      receivedSig,
      runtimeEnv.PAYFAST_PASSPHRASE,
    )
  ) {
    return c.json(
      {
        error: 'INVALID_PAYFAST_SIGNATURE',
        message: 'PayFast ITN MD5 signature verification failed.',
      },
      400,
    );
  }

  const paymentStatus = (payload.payment_status ?? '').toUpperCase();
  if (paymentStatus !== 'COMPLETE') {
    return c.json({
      acknowledged: true,
      paymentStatus,
      settled: false,
    });
  }

  const checkoutId = payload.m_payment_id ?? '';
  const pfPaymentId = payload.pf_payment_id || `pf_${checkoutId}`;
  const amountGrossZar = Number.parseFloat(payload.amount_gross ?? '0');

  const settlement = vhunambiDb.settlePayFastItnAtomic({
    checkoutId,
    pfPaymentId,
    amountGrossZar,
    rawItnPayload: payload,
  });

  if (settlement.outcome === 'checkout_not_found') {
    return c.json({ error: 'CHECKOUT_NOT_FOUND', checkoutId }, 404);
  }
  if (settlement.outcome === 'amount_mismatch') {
    return c.json(
      {
        error: 'AMOUNT_MISMATCH',
        message: 'PayFast amount_gross does not match pending checkout amountZar.',
      },
      422,
    );
  }

  return c.json({
    settled: true,
    idempotentReplay: settlement.outcome === 'idempotent_replay',
    checkoutId,
    pfPaymentId,
    creatorId: settlement.creatorId,
    coinsCredited: settlement.coinsCredited,
    balanceCoins: settlement.balanceCoins,
    balanceZar: settlement.balanceZar,
  });
});

paymentRoutes.get('/payfast/status/:checkoutId', async (c) => {
  const checkoutId = c.req.param('checkoutId');
  const checkout = vhunambiDb.getPayFastCheckout(checkoutId);
  if (!checkout) {
    return c.json({ error: 'CHECKOUT_NOT_FOUND' }, 404);
  }
  const forbidden = assertTenantCreatorAccess(c, checkout.creatorId);
  if (forbidden) return forbidden;

  const wallet = vhunambiDb.getWalletSnapshot(checkout.creatorId);
  return c.json({
    ...checkout,
    walletBalanceCoins: wallet.balanceCoins,
    walletBalanceZar: wallet.balanceZar,
  });
});

paymentRoutes.get('/payfast/packs', (c) => {
  const runtimeEnv = resolveRuntimeEnv(c);
  return c.json({
    success: true,
    sandbox: runtimeEnv.PAYFAST_SANDBOX,
    packs: Object.values(SOVEREIGN_COIN_PACKS),
  });
});

paymentRoutes.post('/payfast/sandbox-settle/:checkoutId', async (c) => {
  const runtimeEnv = resolveRuntimeEnv(c);
  if (!runtimeEnv.PAYFAST_SANDBOX) {
    return c.json(
      {
        error: 'SANDBOX_ONLY',
        message: 'Sandbox settlement endpoint is disabled when PAYFAST_SANDBOX is false.',
      },
      403,
    );
  }

  const checkoutId = c.req.param('checkoutId');
  const checkout = vhunambiDb.getPayFastCheckout(checkoutId);
  if (!checkout) {
    return c.json({ error: 'CHECKOUT_NOT_FOUND', checkoutId }, 404);
  }

  const forbidden = assertTenantCreatorAccess(c, checkout.creatorId);
  if (forbidden) return forbidden;

  const pfPaymentId = `pf_sandbox_${checkoutId}`;
  const itnFields: Record<string, string> = {
    m_payment_id: checkoutId,
    pf_payment_id: pfPaymentId,
    payment_status: 'COMPLETE',
    item_name: checkout.packId,
    amount_gross: Number(checkout.amountZar).toFixed(2),
    custom_str1: checkout.creatorId,
    custom_str2: checkout.packId,
  };
  itnFields.signature = computePayFastSignature(
    itnFields,
    runtimeEnv.PAYFAST_PASSPHRASE,
  );

  const settlement = vhunambiDb.settlePayFastItnAtomic({
    checkoutId,
    pfPaymentId,
    amountGrossZar: Number(checkout.amountZar),
    rawItnPayload: itnFields,
  });

  if (settlement.outcome === 'checkout_not_found') {
    return c.json({ error: 'CHECKOUT_NOT_FOUND', checkoutId }, 404);
  }
  if (settlement.outcome === 'amount_mismatch') {
    return c.json({ error: 'AMOUNT_MISMATCH', checkoutId }, 422);
  }

  return c.json({
    settled: true,
    sandbox: true,
    idempotentReplay: settlement.outcome === 'idempotent_replay',
    checkoutId,
    pfPaymentId,
    creatorId: settlement.creatorId,
    coinsCredited: settlement.coinsCredited,
    balanceCoins: settlement.balanceCoins,
    balanceZar: settlement.balanceZar,
  });
});

