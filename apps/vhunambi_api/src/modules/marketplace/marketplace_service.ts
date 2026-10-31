import { createHash } from 'node:crypto';
import { nanoid } from 'nanoid';
import {
  BeatLicenseCertificate,
  BeatLicenseTier,
  CreateBeatListingRequest,
  LicenseBeatRequest,
  MarketplaceBeatListing,
  MarketplaceFilterQuery,
} from './marketplace_types.js';
import { creditProducerBeatRoyalty } from '../social/social_service.js';

const marketplaceBeats = new Map<string, MarketplaceBeatListing>();
const userLicenses = new Map<string, BeatLicenseCertificate[]>();

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
        zar: Math.round(baseZar * 3),
      };
    case 'unlimited_commercial':
      return {
        coins: Math.round(baseCoins * 6),
        zar: Math.round(baseZar * 6),
      };
  }
}

/** Seed 6 Regional African Master Beats (Phase 28 Marketplace Catalog). */
export function seedMarketplaceBeats(): void {
  if (marketplaceBeats.size > 0) return;

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
      previewAudioUrl: 'https://r2.vhunambi.com/beats/soweto_log_drum.mp3',
      stemPackage: {
        masterAudioUrl: 'https://r2.vhunambi.com/beats/soweto_log_drum.mp3',
        drumsUrl: 'https://r2.vhunambi.com/beats/stems/soweto_drums.wav',
        bassUrl: 'https://r2.vhunambi.com/beats/stems/soweto_bass.wav',
        melodicUrl: 'https://r2.vhunambi.com/beats/stems/soweto_keys.wav',
        otherUrl: 'https://r2.vhunambi.com/beats/stems/soweto_fx.wav',
      },
      salesCount: 14,
      auditionCount: 142,
      licenseTiers: ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
      mmoManifestUrl: 'https://r2.vhunambi.com/manifests/soweto_vip_mmo.json',
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
      previewAudioUrl: 'https://r2.vhunambi.com/beats/durban_quantum.mp3',
      stemPackage: {
        masterAudioUrl: 'https://r2.vhunambi.com/beats/durban_quantum.mp3',
        drumsUrl: 'https://r2.vhunambi.com/beats/stems/durban_drums.wav',
        bassUrl: 'https://r2.vhunambi.com/beats/stems/durban_bass.wav',
        melodicUrl: 'https://r2.vhunambi.com/beats/stems/durban_synths.wav',
        otherUrl: 'https://r2.vhunambi.com/beats/stems/durban_vox.wav',
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
      previewAudioUrl: 'https://r2.vhunambi.com/beats/thohoyandou_pulse.mp3',
      stemPackage: {
        masterAudioUrl: 'https://r2.vhunambi.com/beats/thohoyandou_pulse.mp3',
        drumsUrl: 'https://r2.vhunambi.com/beats/stems/malende_drums.wav',
        bassUrl: 'https://r2.vhunambi.com/beats/stems/malende_bass.wav',
        melodicUrl: 'https://r2.vhunambi.com/beats/stems/malende_flute.wav',
        otherUrl: 'https://r2.vhunambi.com/beats/stems/malende_percussion.wav',
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
      previewAudioUrl: 'https://r2.vhunambi.com/beats/pretoria_rhodes.mp3',
      stemPackage: {
        masterAudioUrl: 'https://r2.vhunambi.com/beats/pretoria_rhodes.mp3',
        drumsUrl: 'https://r2.vhunambi.com/beats/stems/rhodes_drums.wav',
        bassUrl: 'https://r2.vhunambi.com/beats/stems/rhodes_sub.wav',
        melodicUrl: 'https://r2.vhunambi.com/beats/stems/rhodes_keys.wav',
        otherUrl: 'https://r2.vhunambi.com/beats/stems/rhodes_horns.wav',
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
      previewAudioUrl: 'https://r2.vhunambi.com/beats/zululand_guitar.mp3',
      stemPackage: {
        masterAudioUrl: 'https://r2.vhunambi.com/beats/zululand_guitar.mp3',
        drumsUrl: 'https://r2.vhunambi.com/beats/stems/guitar_drums.wav',
        bassUrl: 'https://r2.vhunambi.com/beats/stems/guitar_bass.wav',
        melodicUrl: 'https://r2.vhunambi.com/beats/stems/maskandi_acoustic.wav',
        otherUrl: 'https://r2.vhunambi.com/beats/stems/guitar_congas.wav',
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
      previewAudioUrl: 'https://r2.vhunambi.com/beats/lagos_afrotech.mp3',
      stemPackage: {
        masterAudioUrl: 'https://r2.vhunambi.com/beats/lagos_afrotech.mp3',
        drumsUrl: 'https://r2.vhunambi.com/beats/stems/afrotech_drums.wav',
        bassUrl: 'https://r2.vhunambi.com/beats/stems/afrotech_bass.wav',
        melodicUrl: 'https://r2.vhunambi.com/beats/stems/afrotech_synths.wav',
        otherUrl: 'https://r2.vhunambi.com/beats/stems/afrotech_chords.wav',
      },
      salesCount: 12,
      auditionCount: 130,
      licenseTiers: ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const item of seedItems) {
    marketplaceBeats.set(item.id, item);
  }
}

// Auto-seed on module import
seedMarketplaceBeats();

/**
 * Filtered, paginated public marketplace beats feed.
 */
export function getMarketplaceBeats(
  query: MarketplaceFilterQuery,
): { beats: MarketplaceBeatListing[]; total: number; hasMore: boolean } {
  let list = [...marketplaceBeats.values()];

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
  return marketplaceBeats.get(id) ?? null;
}

/**
 * Upserts a producer's beat into the public marketplace catalog.
 */
export function upsertMarketplaceBeat(
  req: CreateBeatListingRequest,
): MarketplaceBeatListing {
  const now = new Date().toISOString();
  const id = req.id || `beat_${nanoid(8)}`;
  const existing = marketplaceBeats.get(id);

  const priceCoins = req.priceCoins ?? (existing ? existing.priceCoins : 50);
  const priceZar = req.priceZar ?? (existing ? existing.priceZar : 45.0);

  const stemPackage = {
    masterAudioUrl: req.previewAudioUrl,
    drumsUrl: req.stemPackage?.drumsUrl ?? existing?.stemPackage.drumsUrl,
    bassUrl: req.stemPackage?.bassUrl ?? existing?.stemPackage.bassUrl,
    melodicUrl: req.stemPackage?.melodicUrl ?? existing?.stemPackage.melodicUrl,
    otherUrl: req.stemPackage?.otherUrl ?? existing?.stemPackage.otherUrl,
  };

  const listing: MarketplaceBeatListing = {
    id,
    producerId: req.producerId || existing?.producerId || 'creator_user',
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
    stemPackage,
    salesCount: existing ? existing.salesCount : 0,
    auditionCount: existing ? existing.auditionCount : 0,
    licenseTiers: req.licenseTiers ??
      existing?.licenseTiers ?? ['basic_lease', 'stems_trackout', 'unlimited_commercial'],
    mmoManifestUrl: req.mmoManifestUrl ?? existing?.mmoManifestUrl,
    createdAt: existing ? existing.createdAt : now,
    updatedAt: now,
  };

  marketplaceBeats.set(id, listing);
  return listing;
}

/**
 * Removes a beat listing from the public marketplace catalog.
 */
export function deleteMarketplaceBeat(id: string): boolean {
  return marketplaceBeats.delete(id);
}

/**
 * Atomic Licensing Purchase:
 * 1. Validates beat & tier.
 * 2. Generates cryptographic `BeatLicenseCertificate` with unique `licenseHash`.
 * 3. Increments beat sales count.
 * 4. Routes 85% of Coins and ZAR directly into the seller's Creator Wallet!
 */
export function licenseBeat(
  beatId: string,
  req: LicenseBeatRequest,
): { certificate: BeatLicenseCertificate; beat: MarketplaceBeatListing } | null {
  const beat = marketplaceBeats.get(beatId);
  if (!beat) return null;

  const buyerId = req.buyerId || 'buyer_default';
  const buyerHandle = req.buyerHandle || '@buyer_creator';
  const tier = req.tier || 'basic_lease';

  const pricing = calculateTierPricing(beat.priceCoins, beat.priceZar, tier);
  const issuedAt = new Date().toISOString();
  const certificateId = `CERT-VHB-${nanoid(8).toUpperCase()}`;

  // Deterministic license verification hash
  const hashRaw = `${certificateId}|${beat.id}|${buyerId}|${tier}|${pricing.zar}|${issuedAt}`;
  const licenseHash = createHash('sha256').update(hashRaw).digest('hex');

  // 85% creator royalty split
  const producerRoyaltyZar = Math.round(pricing.zar * 0.85 * 100) / 100;
  const producerRoyaltyCoins = Math.round(pricing.coins * 0.85);

  const commercialTerms = switchTerms(tier, beat.title, buyerHandle);

  const cert: BeatLicenseCertificate = {
    certificateId,
    licenseHash,
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
    stemUrls: beat.stemPackage,
  };

  // 1. Increment sales count
  beat.salesCount += 1;

  // 2. Route 85% royalties to producer's wallet via social_service
  creditProducerBeatRoyalty(
    beat.producerId,
    producerRoyaltyZar,
    producerRoyaltyCoins,
    `Beat license sale: "${beat.title}" (${tier.replaceAll('_', ' ')}) to ${buyerHandle}`,
    buyerHandle,
  );

  // 3. Record in user's licenses
  const existing = userLicenses.get(buyerId) ?? [];
  userLicenses.set(buyerId, [cert, ...existing]);

  return { certificate: cert, beat };
}

function switchTerms(tier: BeatLicenseTier, title: string, buyer: string): string {
  switch (tier) {
    case 'basic_lease':
      return `Non-exclusive commercial sync lease for "${title}" granted to ${buyer}. Up to 100,000 monetized streams. Lossless WAV master included.`;
    case 'stems_trackout':
      return `Non-exclusive stems trackout sync license for "${title}" granted to ${buyer}. Up to 500,000 monetized streams. 4 isolated stems (Drums, Bass, Melodic, Other) included.`;
    case 'unlimited_commercial':
      return `Unlimited worldwide commercial license for "${title}" granted to ${buyer}. Unlimited streaming, broadcast, and sync distribution across all platforms.`;
  }
}

/**
 * Returns all licenses and certificates purchased by a buyer.
 */
export function getLicensesByBuyer(buyerId: string): BeatLicenseCertificate[] {
  return userLicenses.get(buyerId) ?? [];
}

/**
 * Returns beats created by a specific producer.
 */
export function getProducerBeats(producerId: string): MarketplaceBeatListing[] {
  return [...marketplaceBeats.values()].filter((b) => b.producerId === producerId);
}

