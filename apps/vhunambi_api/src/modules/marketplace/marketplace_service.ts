import { createHash } from 'node:crypto';
import { nanoid } from 'nanoid';
import { resolveMediaUrl } from '../../config/env.js';
import {
  canonicalizeCreatorId,
  vhunambiDb,
} from '../../db/vhunambi_db.js';
import {
  BeatLicenseCertificate,
  BeatLicenseTier,
  CreateBeatListingRequest,
  LicenseBeatRequest,
  MarketplaceBeatListing,
  MarketplaceFilterQuery,
} from './marketplace_types.js';

function normalizeListingMedia(listing: MarketplaceBeatListing): MarketplaceBeatListing {
  return {
    ...listing,
    previewAudioUrl: resolveMediaUrl(listing.previewAudioUrl),
    stemPackage: {
      masterAudioUrl: resolveMediaUrl(listing.stemPackage?.masterAudioUrl ?? listing.previewAudioUrl),
      drumsUrl: listing.stemPackage?.drumsUrl ? resolveMediaUrl(listing.stemPackage.drumsUrl) : undefined,
      bassUrl: listing.stemPackage?.bassUrl ? resolveMediaUrl(listing.stemPackage.bassUrl) : undefined,
      melodicUrl: listing.stemPackage?.melodicUrl ? resolveMediaUrl(listing.stemPackage.melodicUrl) : undefined,
      otherUrl: listing.stemPackage?.otherUrl ? resolveMediaUrl(listing.stemPackage.otherUrl) : undefined,
    },
    mmoManifestUrl: listing.mmoManifestUrl ? resolveMediaUrl(listing.mmoManifestUrl) : undefined,
  };
}

export type LicenseBeatResult =
  | {
      ok: true;
      certificate: BeatLicenseCertificate;
      beat: MarketplaceBeatListing;
    }
  | {
      ok: false;
      errorCode: 'NOT_FOUND' | 'EXCLUSIVE_CONFLICT' | 'INSUFFICIENT_FUNDS';
      error: string;
    };

function normalizeTierSlug(raw: string | undefined): BeatLicenseTier {
  switch (raw) {
    case 'basic_lease':
      return 'basic_lease';
    case 'stems_trackout':
      return 'stems_trackout';
    case 'unlimited_commercial':
      return 'unlimited_commercial';
    case 'exclusive':
    case 'exclusive_stem':
      return 'exclusive_stem';
    default:
      return 'basic_lease';
  }
}

/** Pricing multipliers by licensing tier. */
function calculateTierPricing(
  baseCoins: number,
  baseZar: number,
  tier: BeatLicenseTier,
): { coins: number; zar: number } {
  switch (tier) {
    case 'basic_lease':
      return { coins: baseCoins, zar: baseZar };
    case 'stems_trackout':
      return {
        coins: Math.round(baseCoins * 3),
        zar: Math.round(baseZar * 3 * 100) / 100,
      };
    case 'exclusive_stem':
    case 'unlimited_commercial':
      return {
        coins: Math.round(baseCoins * 6),
        zar: Math.round(baseZar * 6 * 100) / 100,
      };
  }
}

/** Seed 6 Regional African Master Beats (Phase 28 Marketplace Catalog). */
export function seedMarketplaceBeats(): void {
  if (vhunambiDb.countMarketplaceBeats() > 0) return;

  const now = new Date().toISOString();
  const seedItems: MarketplaceBeatListing[] = [
    {
      id: 'beat_seed_001',
      producerId: 'creator_kabza',
      producerHandle: '@kabza_de_venda',
      producerName: 'Kabza De Venda',
      title: 'Soweto Log-Drum VIP',
      genre: 'Amapiano',
      bpm: 113,
      musicalKey: 'F# Minor',
      tags: ['Log Drum', 'Soweto', 'VIP', 'Deep House'],
      priceCoins: 50,
      priceZar: 45.0,
      previewAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/soweto_log_drum.mp3'),
      stemPackage: {
        masterAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/soweto_log_drum.mp3'),
        drumsUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/soweto_drums.wav'),
        bassUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/soweto_bass.wav'),
        melodicUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/soweto_keys.wav'),
        otherUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/soweto_fx.wav'),
      },
      salesCount: 14,
      auditionCount: 142,
      licenseTiers: ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
      mmoManifestUrl: resolveMediaUrl('https://r2.vhunambi.com/manifests/soweto_vip_mmo.json'),
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'beat_seed_002',
      producerId: 'creator_distruction',
      producerHandle: '@distruction_boyz_fan',
      producerName: 'Durban Heavyweights',
      title: 'Durban Gqom Quantum',
      genre: 'Gqom',
      bpm: 127,
      musicalKey: 'C Minor',
      tags: ['Gqom', 'Durban', 'Raw Kick', 'Warehouse'],
      priceCoins: 60,
      priceZar: 55.0,
      previewAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/durban_quantum.mp3'),
      stemPackage: {
        masterAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/durban_quantum.mp3'),
        drumsUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/durban_drums.wav'),
        bassUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/durban_bass.wav'),
        melodicUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/durban_synths.wav'),
        otherUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/durban_vox.wav'),
      },
      salesCount: 9,
      auditionCount: 98,
      licenseTiers: ['basic_lease', 'stems_trackout'],
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'beat_seed_003',
      producerId: 'creator_makhadzi',
      producerHandle: '@makhadzi',
      producerName: 'Makhadzi',
      title: 'Thohoyandou Malende Pulse',
      genre: 'Afro-Indigenous',
      bpm: 108,
      musicalKey: 'G Minor',
      tags: ['Tshivenḓa', 'Malende', 'Folk', 'Ngoma'],
      priceCoins: 40,
      priceZar: 35.0,
      previewAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/thohoyandou_pulse.mp3'),
      stemPackage: {
        masterAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/thohoyandou_pulse.mp3'),
        drumsUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/malende_drums.wav'),
        bassUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/malende_bass.wav'),
        melodicUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/malende_flute.wav'),
        otherUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/malende_percussion.wav'),
      },
      salesCount: 22,
      auditionCount: 215,
      licenseTiers: ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'beat_seed_004',
      producerId: 'creator_kelvin',
      producerHandle: '@kelvin_momo_disciple',
      producerName: 'Kelvin Vibe',
      title: 'Pretoria Private School Rhodes',
      genre: 'Amapiano',
      bpm: 115,
      musicalKey: 'Eb Major',
      tags: ['Private School', 'Rhodes', 'Jazz Keys', 'Pretoria'],
      priceCoins: 70,
      priceZar: 65.0,
      previewAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/pretoria_rhodes.mp3'),
      stemPackage: {
        masterAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/pretoria_rhodes.mp3'),
        drumsUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/rhodes_drums.wav'),
        bassUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/rhodes_sub.wav'),
        melodicUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/rhodes_keys.wav'),
        otherUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/rhodes_horns.wav'),
      },
      salesCount: 18,
      auditionCount: 174,
      licenseTiers: ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'beat_seed_005',
      producerId: 'creator_shwi',
      producerHandle: '@shwi_nomtekhala',
      producerName: 'Shwi Maskandi Master',
      title: 'Zululand Maskandi Guitar Loop',
      genre: 'Maskandi',
      bpm: 122,
      musicalKey: 'D Major',
      tags: ['Maskandi', 'Acoustic Guitar', 'isiZulu', 'Traditional'],
      priceCoins: 45,
      priceZar: 40.0,
      previewAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/zululand_guitar.mp3'),
      stemPackage: {
        masterAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/zululand_guitar.mp3'),
        drumsUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/guitar_drums.wav'),
        bassUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/guitar_bass.wav'),
        melodicUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/maskandi_acoustic.wav'),
        otherUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/guitar_congas.wav'),
      },
      salesCount: 7,
      auditionCount: 65,
      licenseTiers: ['basic_lease', 'stems_trackout'],
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'beat_seed_006',
      producerId: 'creator_asake',
      producerHandle: '@asake_sound',
      producerName: 'Lagos Sound Architect',
      title: 'Lagos Afro-Tech Groove',
      genre: 'Afro-Tech',
      bpm: 124,
      musicalKey: 'A Minor',
      tags: ['Afro-Tech', 'Lagos', 'Hypnotic', 'Synthesizer'],
      priceCoins: 50,
      priceZar: 45.0,
      previewAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/lagos_afrotech.mp3'),
      stemPackage: {
        masterAudioUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/lagos_afrotech.mp3'),
        drumsUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/afrotech_drums.wav'),
        bassUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/afrotech_bass.wav'),
        melodicUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/afrotech_synths.wav'),
        otherUrl: resolveMediaUrl('https://r2.vhunambi.com/beats/stems/afrotech_chords.wav'),
      },
      salesCount: 12,
      auditionCount: 130,
      licenseTiers: ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const item of seedItems) {
    vhunambiDb.upsertMarketplaceBeat(item);
  }
}

function listAllBeatsInternal(includeExclusiveSold = false): MarketplaceBeatListing[] {
  seedMarketplaceBeats();
  return vhunambiDb
    .listMarketplaceBeats(includeExclusiveSold)
    .map((row) => normalizeListingMedia(row as MarketplaceBeatListing));
}

/**
 * Filtered, paginated public marketplace beats feed.
 */
export function getMarketplaceBeats(
  query: MarketplaceFilterQuery,
): { beats: MarketplaceBeatListing[]; total: number; hasMore: boolean } {
  let list = listAllBeatsInternal(false).filter((b) => !b.isExclusiveSold);

  if (query.genre && query.genre !== 'All') {
    const targetGenre = query.genre.toLowerCase();
    list = list.filter((b) => b.genre.toLowerCase() === targetGenre);
  }

  if (query.search && query.search.trim().length > 0) {
    const q = query.search.trim().toLowerCase();
    list = list.filter(
      (b) =>
        b.title.toLowerCase().includes(q) ||
        b.producerName.toLowerCase().includes(q) ||
        b.producerHandle.toLowerCase().includes(q) ||
        b.tags.some((t) => t.toLowerCase().includes(q)) ||
        b.genre.toLowerCase().includes(q),
    );
  }

  if (query.minBpm != null) {
    list = list.filter((b) => b.bpm >= query.minBpm!);
  }
  if (query.maxBpm != null) {
    list = list.filter((b) => b.bpm <= query.maxBpm!);
  }
  if (query.maxPrice != null) {
    list = list.filter((b) => b.priceCoins <= query.maxPrice!);
  }

  // Sort newest first
  list.sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  const offset = query.cursor ? Number.parseInt(query.cursor, 10) || 0 : 0;
  const limit = Math.min(Math.max(1, query.limit ?? 20), 50);
  const page = list.slice(offset, offset + limit);
  const hasMore = offset + limit < list.length;

  return {
    beats: page,
    total: list.length,
    hasMore,
  };
}

export function getBeatById(id: string): MarketplaceBeatListing | null {
  seedMarketplaceBeats();
  const row = vhunambiDb.getMarketplaceBeatById(id);
  return row ? normalizeListingMedia(row as MarketplaceBeatListing) : null;
}

/**
 * Upserts a producer's beat into the public marketplace catalog.
 */
export function upsertMarketplaceBeat(
  req: CreateBeatListingRequest,
): MarketplaceBeatListing {
  const now = new Date().toISOString();
  const id = req.id || `beat_${nanoid(8)}`;
  const existing = getBeatById(id);

  const priceCoins = req.priceCoins ?? (existing ? existing.priceCoins : 50);
  const priceZar = req.priceZar ?? (existing ? existing.priceZar : 45.0);

  const rawStemPackage = {
    masterAudioUrl: req.previewAudioUrl,
    drumsUrl: req.stemPackage?.drumsUrl ?? existing?.stemPackage.drumsUrl,
    bassUrl: req.stemPackage?.bassUrl ?? existing?.stemPackage.bassUrl,
    melodicUrl: req.stemPackage?.melodicUrl ?? existing?.stemPackage.melodicUrl,
    otherUrl: req.stemPackage?.otherUrl ?? existing?.stemPackage.otherUrl,
  };

  const listing: MarketplaceBeatListing = normalizeListingMedia({
    id,
    producerId: canonicalizeCreatorId(req.producerId || existing?.producerId || 'creator_cern'),
    producerHandle: req.producerHandle || existing?.producerHandle || '@user_beats',
    producerName: req.producerName || existing?.producerName || 'User Beats',
    title: req.title,
    genre: req.genre,
    bpm: req.bpm,
    musicalKey: req.musicalKey,
    tags: req.tags ?? existing?.tags ?? ['Instrumental'],
    priceCoins,
    priceZar,
    previewAudioUrl: req.previewAudioUrl,
    stemPackage: rawStemPackage,
    salesCount: existing ? existing.salesCount : 0,
    auditionCount: existing ? existing.auditionCount : 0,
    licenseTiers: req.licenseTiers ??
      existing?.licenseTiers ?? [
        'basic_lease',
        'stems_trackout',
        'exclusive_stem',
        'unlimited_commercial',
      ],
    isExclusiveSold: existing ? existing.isExclusiveSold : false,
    exclusiveBuyerId: existing?.exclusiveBuyerId,
    mmoManifestUrl: req.mmoManifestUrl ?? existing?.mmoManifestUrl,
    createdAt: existing ? existing.createdAt : now,
    updatedAt: now,
  });

  vhunambiDb.upsertMarketplaceBeat(listing);
  return listing;
}

/**
 * Removes a beat listing from the public marketplace catalog.
 */
export function deleteMarketplaceBeat(id: string): boolean {
  seedMarketplaceBeats();
  return vhunambiDb.deleteMarketplaceBeat(id);
}

/**
 * Atomic Licensing Purchase (Phase 58/62 SQLite WAL + SHA-256 Registry):
 * 1. Validates beat, exclusive availability, and server Coin balance.
 * 2. Generates canonical `VHUNAMBI_LIC_V2` SHA-256 hash & commits ACID ledger rows once.
 * 3. Locks exclusive buyouts and increments beat sales count in persistent SQLite.
 */
export function licenseBeat(
  beatId: string,
  req: LicenseBeatRequest,
): LicenseBeatResult {
  const beat = getBeatById(beatId);
  if (!beat) {
    return {
      ok: false,
      errorCode: 'NOT_FOUND',
      error: 'Beat not found',
    };
  }

  if (beat.isExclusiveSold) {
    return {
      ok: false,
      errorCode: 'EXCLUSIVE_CONFLICT',
      error: 'Beat has already been purchased under an Exclusive license',
    };
  }

  const buyerId = canonicalizeCreatorId(req.buyerId || 'buyer_default');
  const buyerHandle = req.buyerHandle || '@buyer_creator';
  const tier = normalizeTierSlug(req.tier);
  const isExclusive =
    tier === 'exclusive_stem' || tier === 'unlimited_commercial';

  const pricing = calculateTierPricing(beat.priceCoins, beat.priceZar, tier);
  const issuedAt = req.issuedAt || new Date().toISOString();
  const certificateId =
    req.certificateId || `CERT-VHB-${nanoid(8).toUpperCase()}`;

  // 85% creator royalty split
  const producerRoyaltyZar = Math.round(pricing.zar * 0.85 * 100) / 100;
  const producerRoyaltyCoins = Math.floor((pricing.coins * 85 + 50) / 100);
  const commercialTerms = switchTerms(tier, beat.title, buyerHandle);
  const masterDigest =
    req.masterFileSha256 ||
    createHash('sha256').update(beat.id).digest('hex');

  const provisionalCert: BeatLicenseCertificate = {
    certificateId,
    licenseHash: '',
    beatId: beat.id,
    beatTitle: beat.title,
    producerId: beat.producerId,
    producerHandle: beat.producerHandle,
    buyerId,
    buyerHandle,
    tier,
    amountPaidCoins: pricing.coins,
    amountPaidZar: pricing.zar,
    producerRoyaltyZar,
    producerRoyaltyCoins,
    issuedAt,
    commercialTerms,
    masterFileSha256: masterDigest,
    stemUrls: beat.stemPackage,
  };

  const enforceWallet =
    req.enforceWalletBalance ?? vhunambiDb.hasWalletActivity(buyerId);
  const dbRes = vhunambiDb.recordBeatLicenseAtomic({
    certificateId,
    beatId: beat.id,
    beatTitle: beat.title,
    producerId: beat.producerId,
    producerHandle: beat.producerHandle,
    buyerId,
    buyerHandle,
    tierSlug: tier,
    amountPaidCoins: pricing.coins,
    amountPaidZar: pricing.zar,
    producerRoyaltyCoins,
    producerRoyaltyZar,
    issuedAt,
    commercialTerms,
    masterFileSha256: masterDigest,
    isExclusive,
    enforceBuyerWallet: enforceWallet,
    dataJson: provisionalCert as unknown as Record<string, any>,
  });

  if (dbRes.status === 'exclusive_conflict') {
    vhunambiDb.updateMarketplaceBeatSaleState(beat.id, { isExclusiveSold: true });
    return {
      ok: false,
      errorCode: 'EXCLUSIVE_CONFLICT',
      error: 'Beat has already been purchased under an Exclusive license',
    };
  }
  if (dbRes.status === 'insufficient_funds') {
    return {
      ok: false,
      errorCode: 'INSUFFICIENT_FUNDS',
      error: 'Insufficient Coins balance for selected licensing tier',
    };
  }

  const cert: BeatLicenseCertificate = {
    ...provisionalCert,
    licenseHash: dbRes.licenseHash!,
    masterFileSha256: dbRes.masterFileSha256 ?? masterDigest,
  };

  // Update persistent beat salesCount & exclusive lock state in SQLite (royalty already committed in recordBeatLicenseAtomic)
  const updatedBeatRow = vhunambiDb.updateMarketplaceBeatSaleState(beat.id, {
    isExclusiveSold: isExclusive ? true : undefined,
    exclusiveBuyerId: isExclusive ? buyerId : undefined,
  });
  const updatedBeat = updatedBeatRow
    ? normalizeListingMedia(updatedBeatRow as MarketplaceBeatListing)
    : {
        ...beat,
        salesCount: beat.salesCount + 1,
        isExclusiveSold: isExclusive ? true : beat.isExclusiveSold,
        exclusiveBuyerId: isExclusive ? buyerId : beat.exclusiveBuyerId,
      };

  return { ok: true, certificate: cert, beat: updatedBeat };
}

function switchTerms(tier: BeatLicenseTier, title: string, buyer: string): string {
  switch (tier) {
    case 'basic_lease':
      return `Non-exclusive commercial sync lease for "${title}" granted to ${buyer}. Up to 100,000 monetized streams. Lossless WAV master included.`;
    case 'stems_trackout':
      return `Non-exclusive stems trackout sync license for "${title}" granted to ${buyer}. Up to 500,000 monetized streams. 4 isolated stems (Drums, Bass, Melodic, Other) included.`;
    case 'exclusive_stem':
    case 'unlimited_commercial':
      return `Exclusive worldwide commercial master buyout license for "${title}" granted to ${buyer}. Unlimited streaming, broadcast, sync distribution, and 4 isolated stems.`;
  }
}

/**
 * Returns all licenses and certificates purchased by a buyer.
 */
export function getLicensesByBuyer(buyerId: string): BeatLicenseCertificate[] {
  const canonicalBuyer = canonicalizeCreatorId(buyerId);
  return vhunambiDb.getBeatLicensesByBuyer(canonicalBuyer) as BeatLicenseCertificate[];
}

/**
 * Returns beats created by a specific producer.
 */
export function getProducerBeats(producerId: string): MarketplaceBeatListing[] {
  const canonicalProducer = canonicalizeCreatorId(producerId);
  return listAllBeatsInternal(true).filter(
    (b) => canonicalizeCreatorId(b.producerId) === canonicalProducer,
  );
}

