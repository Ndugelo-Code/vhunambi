# Phase 59 — Full-Stack Backend API Convergence (`apps/vhunambi_api` & `apps/vhunambi_client`)
## Detailed Technical Design & Complete Implementation Blueprint

**Document ID**: `VH-DESIGN-P59-FULLSTACK-CONVERGENCE`  
**Phase**: `59`  
**Status**: `ARGON-HARDENED SPECIFICATION (100% COMPILABLE CODE)`  
**Engineering Standard**: All-Gemini Engineering Standard (`STD-ARCH-P59` / `STD-UIUX-001` / `STD-SYNC-039`)

---

## 1. Backend SQLite WAL Engine Upgrade (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

### 1.1 Canonical South African Bank Registry, Playlist Types & Explore Types
In `apps/vhunambi_api/src/db/vhunambi_db.ts`, we add the `playlists` table to `initSchema()`, seed 12 `explore_tracks` rows + 2 `playlists` rows inside `seedInitialDataIfEmpty()`, normalize South African banking + payment rails (`Capitec Pay`, `Ozow`, `PayFast`, `Standard EFT`), and extend `applyMutationsBatch()` to support `library_track`, `playlist`, `payout`, and `track`.

```typescript
// apps/vhunambi_api/src/db/vhunambi_db.ts (Type Definitions & SA Banking Registry)

export interface SaBankMetadata {
  canonicalName: string;
  code: string;
  universalBranchCode: string;
  supportsCapitecPay: boolean;
  supportsOzow: boolean;
  supportsPayFast: boolean;
}

export const SA_BANK_REGISTRY: Record<string, SaBankMetadata> = {
  capitec: {
    canonicalName: 'Capitec Bank',
    code: 'CAPITEC',
    universalBranchCode: '470010',
    supportsCapitecPay: true,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'capitec bank': {
    canonicalName: 'Capitec Bank',
    code: 'CAPITEC',
    universalBranchCode: '470010',
    supportsCapitecPay: true,
    supportsOzow: true,
    supportsPayFast: true,
  },
  fnb: {
    canonicalName: 'FNB',
    code: 'FNB',
    universalBranchCode: '250655',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'first national bank': {
    canonicalName: 'FNB',
    code: 'FNB',
    universalBranchCode: '250655',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'standard bank': {
    canonicalName: 'Standard Bank',
    code: 'SBSA',
    universalBranchCode: '051001',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  nedbank: {
    canonicalName: 'Nedbank',
    code: 'NEDBANK',
    universalBranchCode: '198765',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  absa: {
    canonicalName: 'Absa Bank',
    code: 'ABSA',
    universalBranchCode: '632005',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'absa bank': {
    canonicalName: 'Absa Bank',
    code: 'ABSA',
    universalBranchCode: '632005',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  tymebank: {
    canonicalName: 'TymeBank',
    code: 'TYME',
    universalBranchCode: '678910',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
  'tyme bank': {
    canonicalName: 'TymeBank',
    code: 'TYME',
    universalBranchCode: '678910',
    supportsCapitecPay: false,
    supportsOzow: true,
    supportsPayFast: true,
  },
};

export type PaymentRailId = 'capitec_pay' | 'ozow' | 'payfast' | 'eft';

export interface ExploreTrackRecord {
  id: string;
  title: string;
  artist: string;
  creatorId: string;
  creatorHandle: string;
  genre: string;
  subGenre: string;
  province: string;
  bpm: number;
  musicalKey: string;
  audioUrl: string;
  coverUrl: string;
  durationMs: number;
  likesCount: number;
  playsCount: number;
  cosignsCount: number;
  commentsCount: number;
  sharesCount: number;
  stemsAvailable: boolean;
  discoveryStage: 'freshCrate' | 'risingBreakout' | 'mainstage';
  trendingScore: number;
  songDna: Record<string, unknown>;
  createdAt: string;
}

export interface PlaylistRecord {
  id: string;
  creator_id: string;
  title: string;
  description: string;
  cover_image_url: string | null;
  track_ids: string[];
  is_public: boolean;
  share_code: string | null;
  share_url: string | null;
  created_at: string;
  updated_at: string;
}
```

### 1.2 SQLite Schema Addition (`playlists` Table) & Seed Data (`explore_tracks` + `playlists`)
Inside `VhunambiDatabase.initSchema()` in `apps/vhunambi_api/src/db/vhunambi_db.ts`, append the `playlists` table and index:

```sql
CREATE TABLE IF NOT EXISTS playlists (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL DEFAULT 'usr_me',
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  cover_image_url TEXT,
  track_ids_json TEXT NOT NULL DEFAULT '[]',
  is_public INTEGER NOT NULL DEFAULT 0,
  share_code TEXT,
  share_url TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_playlists_creator ON playlists(creator_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_explore_tracks_genre ON explore_tracks(genre, plays_count DESC);
```

Inside `VhunambiDatabase.seedInitialDataIfEmpty()`, after seeding `creators`, `kinetic_posts`, `beat_listings`, and `collab_bounties`, check and seed `explore_tracks` and `playlists`:

```typescript
// Inside VhunambiDatabase.seedInitialDataIfEmpty()
const trackCount = (
  this.db.prepare('SELECT COUNT(*) as cnt FROM explore_tracks').get() as { cnt: number }
).cnt;

if (trackCount === 0) {
  const now = new Date().toISOString();
  const insertTrack = this.db.prepare(`
    INSERT INTO explore_tracks (
      id, title, artist, creator_id, genre, sub_genre, province, bpm, musical_key,
      audio_url, cover_url, duration_ms, likes_count, plays_count, cosigns_count,
      stems_available, song_dna_json, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const seedTracks: Array<[
    string, string, string, string, string, string, string, number, string,
    string, string, number, number, number, number, number, string, string
  ]> = [
    [
      'trk_cloud_1', 'Sovereign Groove (Quantum Mix)', 'Kabza Spirit', 'usr_amapiano_king',
      'Amapiano', 'Private School', 'Gauteng', 113.0, 'Fm',
      'https://cdn.vhunambi.za/audio/sovereign_groove.wav',
      'https://cdn.vhunambi.za/covers/sovereign_groove.jpg',
      225000, 1420, 14800, 312, 1,
      JSON.stringify({ commentsCount: 89, sharesCount: 210, creatorHandle: '@kabza_spirit' }),
      new Date(Date.now() - 4 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_2', 'Tzaneen Sun (Lekompo Anthem)', 'Kharishma Wave', 'usr_limpopo_wave',
      'Lekompo', 'Bolobedu', 'Limpopo', 116.0, 'Am',
      'https://cdn.vhunambi.za/audio/tzaneen_sun.wav',
      'https://cdn.vhunambi.za/covers/tzaneen_sun.jpg',
      198000, 980, 9400, 265, 1,
      JSON.stringify({ commentsCount: 64, sharesCount: 185, creatorHandle: '@kharishma_wave' }),
      new Date(Date.now() - 6 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_3', 'Durban 3-Step Horizon', 'Dlala Thukzin', 'usr_durban_gqom',
      '3-Step', 'Afro-Tech', 'KwaZulu-Natal', 118.0, 'Cm',
      'https://cdn.vhunambi.za/audio/durban_3step.wav',
      'https://cdn.vhunambi.za/covers/durban_3step.jpg',
      252000, 1650, 18200, 410, 1,
      JSON.stringify({ commentsCount: 142, sharesCount: 390, creatorHandle: '@dlala_thukzin' }),
      new Date(Date.now() - 12 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_4', 'Soweto Midnight Log Drum', 'Kelvin Momo', 'usr_amapiano_king',
      'Amapiano', 'Sgija', 'Gauteng', 112.0, 'Gm',
      'https://cdn.vhunambi.za/audio/soweto_log_drum.wav',
      'https://cdn.vhunambi.za/covers/soweto_log_drum.jpg',
      290000, 820, 4600, 134, 1,
      JSON.stringify({ commentsCount: 53, sharesCount: 97, creatorHandle: '@kelvin_momo' }),
      new Date(Date.now() - 18 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_5', 'Umlazi Bunker Dub', 'Que DJ', 'usr_durban_gqom',
      'Gqom', 'Core Gqom', 'KwaZulu-Natal', 127.0, 'Dm',
      'https://cdn.vhunambi.za/audio/umlazi_bunker.wav',
      'https://cdn.vhunambi.za/covers/umlazi_bunker.jpg',
      210000, 490, 2300, 88, 0,
      JSON.stringify({ commentsCount: 31, sharesCount: 64, creatorHandle: '@que_dj' }),
      new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_6', 'Mamelodi Bacardi Bounce', 'Mellow & Sleazy', 'usr_amapiano_king',
      'Bacardi', 'Pitori Bacardi', 'Gauteng', 114.0, 'Em',
      'https://cdn.vhunambi.za/audio/mamelodi_bacardi.wav',
      'https://cdn.vhunambi.za/covers/mamelodi_bacardi.jpg',
      204000, 610, 3100, 112, 1,
      JSON.stringify({ commentsCount: 44, sharesCount: 82, creatorHandle: '@mellow_sleazy' }),
      new Date(Date.now() - 30 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_7', 'Lagos to Jozi Express', 'Burna Boy', 'usr_me',
      'Afrobeats', 'Afro-Fusion', 'Gauteng', 106.0, 'F#m',
      'https://cdn.vhunambi.za/audio/lagos_jozi.wav',
      'https://cdn.vhunambi.za/covers/lagos_jozi.jpg',
      195000, 2100, 24500, 520, 0,
      JSON.stringify({ commentsCount: 215, sharesCount: 480, creatorHandle: '@burna_afro' }),
      new Date(Date.now() - 36 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_8', 'Giyani Marimba Warp (184 BPM)', 'Sho Madjozi', 'usr_limpopo_wave',
      'Shangaan Electro', 'Tsonga Warp', 'Limpopo', 184.0, 'C',
      'https://cdn.vhunambi.za/audio/giyani_warp.wav',
      'https://cdn.vhunambi.za/covers/giyani_warp.jpg',
      168000, 340, 1180, 42, 1,
      JSON.stringify({ commentsCount: 19, sharesCount: 38, creatorHandle: '@sho_madjozi' }),
      new Date(Date.now() - 8 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_9', 'Zululand Acoustic Soul', 'Sjava', 'usr_durban_gqom',
      'Maskandi', 'Trap-Maskandi', 'KwaZulu-Natal', 98.0, 'G',
      'https://cdn.vhunambi.za/audio/zululand_soul.wav',
      'https://cdn.vhunambi.za/covers/zululand_soul.jpg',
      236000, 740, 5200, 155, 1,
      JSON.stringify({ commentsCount: 68, sharesCount: 120, creatorHandle: '@sjava_indawo' }),
      new Date(Date.now() - 40 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_10', 'Zola 7 Heritage Groove', 'Mandoza Legacy', 'usr_amapiano_king',
      'Kwaito', '90s Kwaito', 'Gauteng', 105.0, 'Am',
      'https://cdn.vhunambi.za/audio/zola_heritage.wav',
      'https://cdn.vhunambi.za/covers/zola_heritage.jpg',
      244000, 530, 2890, 96, 0,
      JSON.stringify({ commentsCount: 37, sharesCount: 71, creatorHandle: '@kwaito_roots' }),
      new Date(Date.now() - 48 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_11', 'Clifton Sunset Deep', 'Black Coffee', 'usr_me',
      'Afro-Tech', 'Deep Afro', 'Western Cape', 120.0, 'Bm',
      'https://cdn.vhunambi.za/audio/clifton_sunset.wav',
      'https://cdn.vhunambi.za/covers/clifton_sunset.jpg',
      310000, 1890, 21400, 490, 1,
      JSON.stringify({ commentsCount: 160, sharesCount: 410, creatorHandle: '@realblackcoffee' }),
      new Date(Date.now() - 52 * 3600 * 1000).toISOString(),
    ],
    [
      'trk_cloud_12', 'Pretoria Dub Chord Study', 'Jullian Gomes', 'usr_me',
      'Deep House', 'SA Deep', 'Gauteng', 117.0, 'Dm',
      'https://cdn.vhunambi.za/audio/pretoria_dub.wav',
      'https://cdn.vhunambi.za/covers/pretoria_dub.jpg',
      268000, 290, 920, 34, 1,
      JSON.stringify({ commentsCount: 14, sharesCount: 29, creatorHandle: '@jullian_gomes' }),
      now,
    ],
  ];

  const txTracks = this.db.transaction(() => {
    for (const row of seedTracks) {
      insertTrack.run(...row);
    }
  });
  txTracks();
}

const playlistCount = (
  this.db.prepare('SELECT COUNT(*) as cnt FROM playlists').get() as { cnt: number }
).cnt;

if (playlistCount === 0) {
  const now = new Date().toISOString();
  const insertPlaylist = this.db.prepare(`
    INSERT INTO playlists (
      id, creator_id, title, description, cover_image_url, track_ids_json,
      is_public, share_code, share_url, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  insertPlaylist.run(
    'pl_amapiano_gold',
    'usr_me',
    'Amapiano & Lekompo Gold',
    'Curated Private School Amapiano and Limpopo Lekompo rotation.',
    'https://cdn.vhunambi.za/covers/sovereign_groove.jpg',
    JSON.stringify(['trk_cloud_1', 'trk_cloud_2', 'trk_cloud_4', 'trk_cloud_6']),
    1,
    'VH-AMAPIANO-01',
    'https://vhunambi.za/p/VH-AMAPIANO-01',
    now,
    now
  );
  insertPlaylist.run(
    'pl_3step_horizon',
    'usr_me',
    '3-Step & Afro-Tech Horizon',
    'High-energy Durban 3-Step and Cape Town Afro-Tech dubs.',
    'https://cdn.vhunambi.za/covers/durban_3step.jpg',
    JSON.stringify(['trk_cloud_3', 'trk_cloud_11', 'trk_cloud_5']),
    0,
    null,
    null,
    now,
    now
  );
}
```

### 1.3 Explore Catalog, Trending Velocity, Genre Filter & Radio Rotation Methods (`vhunambi_db.ts`)
We upgrade `getExploreFeed()` so it respects `options.genre` in SQL, and we add `getExploreTracks()`, `upsertExploreTrack()`, `getExploreRadioRotation()`, and `getExploreDiscoveryBundle()`:

```typescript
// Inside VhunambiDatabase (apps/vhunambi_api/src/db/vhunambi_db.ts)

private computeTrackTrendingAndStage(row: Record<string, unknown>): ExploreTrackRecord {
  const plays = Number(row.plays_count ?? 0);
  const likes = Number(row.likes_count ?? 0);
  const cosigns = Number(row.cosigns_count ?? 0);
  const stemsAvailable = Number(row.stems_available ?? 0) === 1;
  const createdAtStr = String(row.created_at ?? new Date().toISOString());
  const ageDays = Math.max(
    0,
    (Date.now() - new Date(createdAtStr).getTime()) / (1000 * 60 * 60 * 24)
  );
  const recencyBonus = Math.max(0, 15.0 - 0.5 * ageDays);
  const stemsBonus = stemsAvailable ? 6.0 : 0.0;
  const rawScore =
    18.0 * Math.log(1 + plays) +
    2.4 * Math.sqrt(likes) +
    3.8 * Math.sqrt(cosigns) +
    stemsBonus +
    recencyBonus;
  const trendingScore = Number(Math.min(100, Math.max(0, rawScore)).toFixed(2));

  let discoveryStage: 'freshCrate' | 'risingBreakout' | 'mainstage' = 'freshCrate';
  if (plays >= 8000 || cosigns >= 250 || trendingScore >= 82.0) {
    discoveryStage = 'mainstage';
  } else if (plays >= 1500 || cosigns >= 60 || trendingScore >= 58.0) {
    discoveryStage = 'risingBreakout';
  }

  let songDna: Record<string, unknown> = {};
  try {
    songDna = JSON.parse(String(row.song_dna_json ?? '{}')) as Record<string, unknown>;
  } catch {
    songDna = {};
  }

  return {
    id: String(row.id),
    title: String(row.title),
    artist: String(row.artist),
    creatorId: String(row.creator_id ?? 'usr_me'),
    creatorHandle: String(songDna.creatorHandle ?? `@${String(row.artist).toLowerCase().replace(/\s+/g, '_')}`),
    genre: String(row.genre ?? 'Amapiano'),
    subGenre: String(row.sub_genre ?? 'Sgija'),
    province: String(row.province ?? 'Gauteng'),
    bpm: Number(row.bpm ?? 113),
    musicalKey: String(row.musical_key ?? 'Am'),
    audioUrl: String(row.audio_url ?? ''),
    coverUrl: String(row.cover_url ?? ''),
    durationMs: Number(row.duration_ms ?? 180000),
    likesCount: likes,
    playsCount: plays,
    cosignsCount: cosigns,
    commentsCount: Number(songDna.commentsCount ?? Math.round(likes * 0.08)),
    sharesCount: Number(songDna.sharesCount ?? Math.round(cosigns * 0.65)),
    stemsAvailable,
    discoveryStage,
    trendingScore,
    songDna,
    createdAt: createdAtStr,
  };
}

public getExploreTracks(options: {
  genre?: string;
  stage?: string;
  sort?: 'trending' | 'newest' | 'likes' | 'plays';
  search?: string;
  limit?: number;
}): { items: ExploreTrackRecord[]; total: number; serverSeq: number } {
  const limit = Math.min(Math.max(options.limit ?? 50, 1), 100);
  const rows = this.db
    .prepare('SELECT * FROM explore_tracks ORDER BY created_at DESC')
    .all() as Array<Record<string, unknown>>;

  let mapped = rows.map((r) => this.computeTrackTrendingAndStage(r));

  if (options.genre && options.genre.trim() !== '' && options.genre.toLowerCase() !== 'all') {
    const g = options.genre.trim().toLowerCase();
    mapped = mapped.filter(
      (t) => t.genre.toLowerCase() === g || t.subGenre.toLowerCase() === g
    );
  }

  if (options.stage && options.stage.trim() !== '' && options.stage.toLowerCase() !== 'all') {
    const st = options.stage.trim().toLowerCase();
    mapped = mapped.filter((t) => t.discoveryStage.toLowerCase() === st);
  }

  if (options.search && options.search.trim() !== '') {
    const q = options.search.trim().toLowerCase();
    mapped = mapped.filter(
      (t) =>
        t.title.toLowerCase().includes(q) ||
        t.artist.toLowerCase().includes(q) ||
        t.genre.toLowerCase().includes(q) ||
        t.province.toLowerCase().includes(q)
    );
  }

  const sortMode = options.sort ?? 'trending';
  mapped.sort((a, b) => {
    if (sortMode === 'newest') {
      return b.createdAt.localeCompare(a.createdAt);
    }
    if (sortMode === 'likes') {
      return b.likesCount - a.likesCount;
    }
    if (sortMode === 'plays') {
      return b.playsCount - a.playsCount;
    }
    return b.trendingScore - a.trendingScore;
  });

  return {
    items: mapped.slice(0, limit),
    total: mapped.length,
    serverSeq: this.getLatestSeq(),
  };
}

public getExploreRadioRotation(genre: string, limit = 20): {
  genre: string;
  stationTitle: string;
  description: string;
  seedBpm: number;
  rotation: ExploreTrackRecord[];
  serverSeq: number;
} {
  const normalizedGenre = !genre || genre.toLowerCase() === 'all' ? 'All' : genre;
  const { items } = this.getExploreTracks({
    genre: normalizedGenre === 'All' ? undefined : normalizedGenre,
    sort: 'trending',
    limit: 100,
  });

  const pool = items.length > 0 ? items : this.getExploreTracks({ limit: 50 }).items;
  const seedBpm = pool.length > 0 ? pool[0].bpm : 113;

  // Order by harmonic BPM flow relative to seedBpm combined with trendingScore
  const rotation = [...pool]
    .sort((a, b) => {
      const bpmDiffA = Math.abs(a.bpm - seedBpm);
      const bpmDiffB = Math.abs(b.bpm - seedBpm);
      return bpmDiffA * 1.5 - a.trendingScore * 0.25 - (bpmDiffB * 1.5 - b.trendingScore * 0.25);
    })
    .slice(0, Math.min(Math.max(limit, 1), 50));

  return {
    genre: normalizedGenre,
    stationTitle:
      normalizedGenre === 'All'
        ? 'Sovereign Pan-African Pulse Radio'
        : `${normalizedGenre} Sovereign Radio Rotation`,
    description: `Continuous harmonic ${normalizedGenre} rotation anchored around ${seedBpm} BPM.`,
    seedBpm,
    rotation,
    serverSeq: this.getLatestSeq(),
  };
}

public upsertExploreTrack(payload: Record<string, unknown>): ExploreTrackRecord {
  const now = new Date().toISOString();
  const id = String(payload.id ?? `trk_${Date.now()}`);
  const title = String(payload.title ?? 'Untitled Track');
  const artist = String(payload.artist ?? 'Sovereign Creator');
  const creatorId = String(payload.creatorId ?? payload.creator_id ?? 'usr_me');
  const genre = String(payload.genre ?? 'Amapiano');
  const subGenre = String(payload.subGenre ?? payload.sub_genre ?? genre);
  const province = String(payload.province ?? 'Gauteng');
  const bpm = Number(payload.bpm ?? 113);
  const musicalKey = String(payload.musicalKey ?? payload.key ?? payload.musical_key ?? 'Am');
  const audioUrl = String(payload.audioUrl ?? payload.audio_url ?? '');
  const coverUrl = String(payload.coverUrl ?? payload.cover_url ?? '');
  const durationMs = Number(payload.durationMs ?? payload.duration_ms ?? 180000);
  const likesCount = Number(payload.likesCount ?? payload.likes_count ?? 0);
  const playsCount = Number(payload.playsCount ?? payload.plays_count ?? 0);
  const cosignsCount = Number(payload.cosignsCount ?? payload.cosigns_count ?? 0);
  const stemsAvailable = Boolean(payload.stemsAvailable ?? payload.stems_available ?? false) ? 1 : 0;
  const songDnaJson = JSON.stringify({
    commentsCount: Number(payload.commentsCount ?? 0),
    sharesCount: Number(payload.sharesCount ?? 0),
    creatorHandle: String(payload.creatorHandle ?? `@${artist.toLowerCase().replace(/\s+/g, '_')}`),
  });

  const tx = this.db.transaction(() => {
    this.db
      .prepare(
        `INSERT INTO explore_tracks (
          id, title, artist, creator_id, genre, sub_genre, province, bpm, musical_key,
          audio_url, cover_url, duration_ms, likes_count, plays_count, cosigns_count,
          stems_available, song_dna_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          artist = excluded.artist,
          genre = excluded.genre,
          sub_genre = excluded.sub_genre,
          province = excluded.province,
          bpm = excluded.bpm,
          musical_key = excluded.musical_key,
          audio_url = excluded.audio_url,
          cover_url = excluded.cover_url,
          duration_ms = excluded.duration_ms,
          likes_count = excluded.likes_count,
          plays_count = excluded.plays_count,
          cosigns_count = excluded.cosigns_count,
          stems_available = excluded.stems_available,
          song_dna_json = excluded.song_dna_json`
      )
      .run(
        id, title, artist, creatorId, genre, subGenre, province, bpm, musicalKey,
        audioUrl, coverUrl, durationMs, likesCount, playsCount, cosignsCount,
        stemsAvailable, songDnaJson, now
      );

    this.db
      .prepare(
        `INSERT INTO sync_mutation_log (
          mutation_id, device_id, entity_type, entity_id, operation, payload_json, created_at
        ) VALUES (?, ?, 'track', ?, 'upsert', ?, ?)`
      )
      .run(`mut_trk_${id}_${Date.now()}`, 'api_explore', id, JSON.stringify({ id, title, genre }), now);
  });
  tx();

  const row = this.db
    .prepare('SELECT * FROM explore_tracks WHERE id = ?')
    .get(id) as Record<string, unknown>;
  return this.computeTrackTrendingAndStage(row);
}
```

### 1.4 Library Cloud Delta Sync Engine (`vhunambi_db.ts`)
We upgrade `user_library_sync` handling with `syncLibraryDelta()` implementing deterministic LWW timestamp + monotonic `playCount` + Phase 58 license preservation:

```typescript
// Inside VhunambiDatabase (apps/vhunambi_api/src/db/vhunambi_db.ts)

public syncLibraryDelta(input: {
  creatorId: string;
  items: Array<Record<string, unknown>>;
  deletedIds?: string[];
}): {
  creatorId: string;
  appliedCount: number;
  items: Array<Record<string, unknown>>;
  serverSeq: number;
  syncedAt: string;
} {
  const creatorId = input.creatorId || 'usr_me';
  const now = new Date().toISOString();
  const nowMs = Date.now();
  let appliedCount = 0;

  const selectExisting = this.db.prepare(
    'SELECT * FROM user_library_sync WHERE id = ? AND creator_id = ?'
  );
  const upsertRow = this.db.prepare(`
    INSERT INTO user_library_sync (
      id, creator_id, item_type, title, data_json, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      item_type = excluded.item_type,
      title = excluded.title,
      data_json = excluded.data_json,
      updated_at = excluded.updated_at
  `);
  const deleteRow = this.db.prepare(
    'DELETE FROM user_library_sync WHERE id = ? AND creator_id = ?'
  );
  const insertLog = this.db.prepare(`
    INSERT INTO sync_mutation_log (
      mutation_id, device_id, entity_type, entity_id, operation, payload_json, created_at
    ) VALUES (?, ?, 'library_track', ?, ?, ?, ?)
  `);

  const tx = this.db.transaction(() => {
    if (Array.isArray(input.deletedIds)) {
      for (const delId of input.deletedIds) {
        const info = deleteRow.run(delId, creatorId);
        if (info.changes > 0) {
          appliedCount++;
          insertLog.run(
            `mut_lib_del_${delId}_${Date.now()}_${appliedCount}`,
            'api_library_sync',
            delId,
            'purge',
            JSON.stringify({ id: delId, creatorId }),
            now
          );
        }
      }
    }

    for (const rawItem of input.items ?? []) {
      const id = String(rawItem.id ?? `lib_${Date.now()}_${appliedCount}`);
      const existing = selectExisting.get(id, creatorId) as Record<string, unknown> | undefined;

      let existingData: Record<string, unknown> = {};
      if (existing && typeof existing.data_json === 'string') {
        try {
          existingData = JSON.parse(existing.data_json) as Record<string, unknown>;
        } catch {
          existingData = {};
        }
      }

      const incomingUpdatedMs = Number(
        rawItem.updatedAtMs ??
          (typeof rawItem.updatedAt === 'string' ? Date.parse(rawItem.updatedAt) : nowMs)
      );
      const existingUpdatedMs = Number(
        existingData.updatedAtMs ??
          (existing && typeof existing.updated_at === 'string'
            ? Date.parse(String(existing.updated_at))
            : 0)
      );

      // LWW winner selection with monotonic playCount & non-destructive license preservation
      const incomingWins = !existing || incomingUpdatedMs >= existingUpdatedMs;
      const base = incomingWins
        ? { ...existingData, ...rawItem }
        : { ...rawItem, ...existingData };

      const mergedPlayCount = Math.max(
        Number(rawItem.playCount ?? 0),
        Number(existingData.playCount ?? 0)
      );

      const mergedPayload: Record<string, unknown> = {
        ...base,
        id,
        creatorId,
        playCount: mergedPlayCount,
        licensePurchaseId:
          rawItem.licensePurchaseId ?? existingData.licensePurchaseId ?? null,
        licenseTierId:
          rawItem.licenseTierId ?? existingData.licenseTierId ?? null,
        licenseCertificateHash:
          rawItem.licenseCertificateHash ?? existingData.licenseCertificateHash ?? null,
        producerHandle:
          rawItem.producerHandle ?? existingData.producerHandle ?? null,
        stemFilePaths:
          rawItem.stemFilePaths ?? existingData.stemFilePaths ?? [],
        updatedAtMs: Math.max(incomingUpdatedMs, existingUpdatedMs, nowMs),
      };

      const itemType = String(
        rawItem.itemType ?? (mergedPayload.isStem ? 'stem' : 'track')
      );
      const title = String(mergedPayload.title ?? 'Untitled Track');

      upsertRow.run(
        id,
        creatorId,
        itemType,
        title,
        JSON.stringify(mergedPayload),
        existing ? String(existing.created_at) : now,
        now
      );
      appliedCount++;

      insertLog.run(
        `mut_lib_${id}_${Date.now()}_${appliedCount}`,
        'api_library_sync',
        id,
        'upsert',
        JSON.stringify(mergedPayload),
        now
      );
    }
  });

  tx();

  return {
    creatorId,
    appliedCount,
    items: this.getLibraryItems(creatorId),
    serverSeq: this.getLatestSeq(),
    syncedAt: now,
  };
}
```

### 1.5 Playlists CRUD & Cloud Share Engine (`vhunambi_db.ts`)

```typescript
// Inside VhunambiDatabase (apps/vhunambi_api/src/db/vhunambi_db.ts)

private mapPlaylistRow(row: Record<string, unknown>): PlaylistRecord {
  let trackIds: string[] = [];
  try {
    const parsed = JSON.parse(String(row.track_ids_json ?? '[]'));
    if (Array.isArray(parsed)) {
      trackIds = parsed.map((id) => String(id));
    }
  } catch {
    trackIds = [];
  }

  return {
    id: String(row.id),
    creator_id: String(row.creator_id ?? 'usr_me'),
    title: String(row.title),
    description: String(row.description ?? ''),
    cover_image_url: row.cover_image_url ? String(row.cover_image_url) : null,
    track_ids: trackIds,
    is_public: Number(row.is_public ?? 0) === 1,
    share_code: row.share_code ? String(row.share_code) : null,
    share_url: row.share_url ? String(row.share_url) : null,
    created_at: String(row.created_at),
    updated_at: String(row.updated_at),
  };
}

public getPlaylists(creatorId = 'usr_me', includePublic = true): PlaylistRecord[] {
  const rows = includePublic
    ? (this.db
        .prepare(
          'SELECT * FROM playlists WHERE creator_id = ? OR is_public = 1 ORDER BY updated_at DESC'
        )
        .all(creatorId) as Array<Record<string, unknown>>)
    : (this.db
        .prepare('SELECT * FROM playlists WHERE creator_id = ? ORDER BY updated_at DESC')
        .all(creatorId) as Array<Record<string, unknown>>);
  return rows.map((r) => this.mapPlaylistRow(r));
}

public getPlaylistById(id: string): PlaylistRecord | null {
  const row = this.db
    .prepare('SELECT * FROM playlists WHERE id = ?')
    .get(id) as Record<string, unknown> | undefined;
  return row ? this.mapPlaylistRow(row) : null;
}

public upsertPlaylist(payload: {
  id?: string;
  creatorId?: string;
  title: string;
  description?: string;
  coverImageUrl?: string | null;
  trackIds?: string[];
  isPublic?: boolean;
  shareCode?: string | null;
  shareUrl?: string | null;
}): PlaylistRecord {
  const now = new Date().toISOString();
  const id = payload.id?.trim() || `pl_${Date.now()}`;
  const existing = this.getPlaylistById(id);

  const creatorId = payload.creatorId ?? existing?.creator_id ?? 'usr_me';
  const title = payload.title?.trim() || existing?.title || 'Untitled Playlist';
  const description = payload.description ?? existing?.description ?? '';
  const coverImageUrl =
    payload.coverImageUrl !== undefined ? payload.coverImageUrl : (existing?.cover_image_url ?? null);
  const trackIds = payload.trackIds ?? existing?.track_ids ?? [];
  const isPublic = payload.isPublic !== undefined ? payload.isPublic : (existing?.is_public ?? false);
  const shareCode = payload.shareCode !== undefined ? payload.shareCode : (existing?.share_code ?? null);
  const shareUrl = payload.shareUrl !== undefined ? payload.shareUrl : (existing?.share_url ?? null);
  const createdAt = existing?.created_at ?? now;

  const tx = this.db.transaction(() => {
    this.db
      .prepare(
        `INSERT INTO playlists (
          id, creator_id, title, description, cover_image_url, track_ids_json,
          is_public, share_code, share_url, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          description = excluded.description,
          cover_image_url = excluded.cover_image_url,
          track_ids_json = excluded.track_ids_json,
          is_public = excluded.is_public,
          share_code = excluded.share_code,
          share_url = excluded.share_url,
          updated_at = excluded.updated_at`
      )
      .run(
        id,
        creatorId,
        title,
        description,
        coverImageUrl,
        JSON.stringify(trackIds),
        isPublic ? 1 : 0,
        shareCode,
        shareUrl,
        createdAt,
        now
      );

    this.db
      .prepare(
        `INSERT INTO sync_mutation_log (
          mutation_id, device_id, entity_type, entity_id, operation, payload_json, created_at
        ) VALUES (?, ?, 'playlist', ?, 'upsert', ?, ?)`
      )
      .run(
        `mut_pl_${id}_${Date.now()}`,
        'api_playlists',
        id,
        JSON.stringify({ id, title, track_ids: trackIds, is_public: isPublic }),
        now
      );
  });
  tx();

  return this.getPlaylistById(id)!;
}

public deletePlaylist(id: string): boolean {
  const now = new Date().toISOString();
  let deleted = false;
  const tx = this.db.transaction(() => {
    const info = this.db.prepare('DELETE FROM playlists WHERE id = ?').run(id);
    deleted = info.changes > 0;
    if (deleted) {
      this.db
        .prepare(
          `INSERT INTO sync_mutation_log (
            mutation_id, device_id, entity_type, entity_id, operation, payload_json, created_at
          ) VALUES (?, ?, 'playlist', ?, 'delete', ?, ?)`
        )
        .run(`mut_pl_del_${id}_${Date.now()}`, 'api_playlists', id, JSON.stringify({ id }), now);
    }
  });
  tx();
  return deleted;
}

public sharePlaylist(id: string): {
  playlist: PlaylistRecord;
  shareCode: string;
  shareUrl: string;
  sharedAt: string;
} {
  const existing = this.getPlaylistById(id);
  if (!existing) {
    throw new Error(`Playlist ${id} not found`);
  }
  const cleanSuffix = id.replace(/[^a-zA-Z0-9]/g, '').slice(-6).toUpperCase() || 'SHARED';
  const shareCode = existing.share_code ?? `VH-${cleanSuffix}-${Date.now().toString(36).slice(-4).toUpperCase()}`;
  const shareUrl = `https://vhunambi.za/p/${shareCode}`;
  const updated = this.upsertPlaylist({
    id: existing.id,
    creatorId: existing.creator_id,
    title: existing.title,
    description: existing.description,
    coverImageUrl: existing.cover_image_url,
    trackIds: existing.track_ids,
    isPublic: true,
    shareCode,
    shareUrl,
  });

  return {
    playlist: updated,
    shareCode,
    shareUrl,
    sharedAt: updated.updated_at,
  };
}
```

### 1.6 Unified South African Banking & Gateway Payout Engine (`vhunambi_db.ts`)
We replace `requestPayout()` in `vhunambi_db.ts` (`lines 805–891`) with the normalized SA Bank + Multi-Rail Gateway implementation:

```typescript
// Inside VhunambiDatabase (apps/vhunambi_api/src/db/vhunambi_db.ts)

public requestPayout(input: {
  creatorId: string;
  amountZar: number;
  bankName: string;
  accountNumber: string;
  branchCode?: string;
  paymentRail?: string;
  accountHolder?: string;
}): {
  ledgerId: string;
  creatorId: string;
  amountZar: number;
  feeZar: number;
  netPayoutZar: number;
  newBalanceZar: number;
  bankName: string;
  bankCode: string;
  branchCode: string;
  maskedAccount: string;
  paymentRail: PaymentRailId;
  referenceCode: string;
  status: 'processing_eft' | 'instant_cleared';
  estimatedArrival: string;
  serverSeq: number;
} {
  if (input.amountZar < 50) {
    throw new Error('Minimum payout threshold is R50.00 ZAR');
  }

  const normalizedBankKey = (input.bankName ?? '').trim().toLowerCase();
  const bankMeta = SA_BANK_REGISTRY[normalizedBankKey];
  if (!bankMeta) {
    throw new Error(
      `Unsupported South African bank: ${input.bankName}. Supported: Capitec Bank, FNB, Standard Bank, Nedbank, Absa Bank, TymeBank`
    );
  }

  const digitsOnly = (input.accountNumber ?? '').replace(/\D/g, '');
  if (digitsOnly.length < 8 || digitsOnly.length > 12) {
    throw new Error('Invalid South African bank account number (must be 8-12 digits)');
  }

  const resolvedBranchCode =
    input.branchCode && input.branchCode.trim().length >= 5
      ? input.branchCode.trim()
      : bankMeta.universalBranchCode;

  const rawRail = (input.paymentRail ?? '').trim().toLowerCase();
  let paymentRail: PaymentRailId = 'eft';
  if (rawRail === 'capitec_pay' || (rawRail === '' && bankMeta.supportsCapitecPay)) {
    paymentRail = 'capitec_pay';
  } else if (rawRail === 'ozow') {
    paymentRail = 'ozow';
  } else if (rawRail === 'payfast') {
    paymentRail = 'payfast';
  }

  let feeZar = 0.0;
  let estimatedArrival = '1-2 Business Days (SARB EFT)';
  let refPrefix = 'EFT';
  let status: 'processing_eft' | 'instant_cleared' = 'processing_eft';

  if (paymentRail === 'capitec_pay') {
    feeZar = 2.5;
    estimatedArrival = 'Instant (< 60 sec via Capitec Pay RTC)';
    refPrefix = 'CAPITEC';
    status = 'instant_cleared';
  } else if (paymentRail === 'ozow') {
    feeZar = 3.5;
    estimatedArrival = 'Instant Ozow RTC (< 2 min)';
    refPrefix = 'OZOW';
    status = 'instant_cleared';
  } else if (paymentRail === 'payfast') {
    feeZar = Number(Math.max(5.0, input.amountZar * 0.015).toFixed(2));
    estimatedArrival = 'Same-Day PayFast (< 4 hrs)';
    refPrefix = 'PAYFAST';
    status = 'instant_cleared';
  }

  const netPayoutZar = Number(Math.max(0, input.amountZar - feeZar).toFixed(2));
  const maskedAccount = `****${digitsOnly.slice(-4)}`;
  const referenceCode = `${refPrefix}-${bankMeta.code}-${Date.now().toString(36).toUpperCase()}`;
  const ledgerId = `tx_payout_${Date.now()}`;
  const bankAccountId = `ba_${input.creatorId}_${bankMeta.code.toLowerCase()}`;
  const now = new Date().toISOString();

  let newBalance = 0;

  const tx = this.db.transaction(() => {
    const creator = this.db
      .prepare('SELECT balance_zar, display_name FROM creators WHERE id = ?')
      .get(input.creatorId) as { balance_zar: number; display_name: string } | undefined;
    if (!creator) {
      throw new Error(`Creator ${input.creatorId} not found`);
    }
    if (creator.balance_zar < input.amountZar) {
      throw new Error(
        `Insufficient wallet balance: R${creator.balance_zar.toFixed(2)} < R${input.amountZar.toFixed(2)}`
      );
    }

    this.db
      .prepare('UPDATE creators SET balance_zar = balance_zar - ?, updated_at = ? WHERE id = ?')
      .run(input.amountZar, now, input.creatorId);

    this.db
      .prepare(
        `INSERT INTO bank_accounts (
          id, creator_id, bank_name, account_holder, account_number_masked, branch_code, is_verified, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, 1, ?)
        ON CONFLICT(id) DO UPDATE SET
          bank_name = excluded.bank_name,
          account_holder = excluded.account_holder,
          account_number_masked = excluded.account_number_masked,
          branch_code = excluded.branch_code`
      )
      .run(
        bankAccountId,
        input.creatorId,
        bankMeta.canonicalName,
        input.accountHolder?.trim() || creator.display_name,
        maskedAccount,
        resolvedBranchCode,
        now
      );

    this.db
      .prepare(
        `INSERT INTO wallet_ledger (
          id, creator_id, amount_zar, tx_type, description, reference_id, status, metadata_json, created_at
        ) VALUES (?, ?, ?, 'payout', ?, ?, ?, ?, ?)`
      )
      .run(
        ledgerId,
        input.creatorId,
        -Math.abs(input.amountZar),
        `${paymentRail.toUpperCase()} Payout to ${bankMeta.canonicalName} (${maskedAccount})`,
        referenceCode,
        status,
        JSON.stringify({
          bankName: bankMeta.canonicalName,
          bankCode: bankMeta.code,
          branchCode: resolvedBranchCode,
          maskedAccount,
          paymentRail,
          feeZar,
          netPayoutZar,
          referenceCode,
          estimatedArrival,
        }),
        now
      );

    const updated = this.db
      .prepare('SELECT balance_zar FROM creators WHERE id = ?')
      .get(input.creatorId) as { balance_zar: number };
    newBalance = Number(updated.balance_zar.toFixed(2));

    this.db
      .prepare(
        `INSERT INTO sync_mutation_log (
          mutation_id, device_id, entity_type, entity_id, operation, payload_json, created_at
        ) VALUES (?, ?, 'payout', ?, 'create', ?, ?)`
      )
      .run(
        `mut_payout_${ledgerId}`,
        'api_wallet',
        ledgerId,
        JSON.stringify({
          ledgerId,
          creatorId: input.creatorId,
          amountZar: input.amountZar,
          netPayoutZar,
          newBalanceZar: newBalance,
          bankName: bankMeta.canonicalName,
          maskedAccount,
          paymentRail,
          referenceCode,
        }),
        now
      );
  });

  tx();

  return {
    ledgerId,
    creatorId: input.creatorId,
    amountZar: input.amountZar,
    feeZar,
    netPayoutZar,
    newBalanceZar: newBalance,
    bankName: bankMeta.canonicalName,
    bankCode: bankMeta.code,
    branchCode: resolvedBranchCode,
    maskedAccount,
    paymentRail,
    referenceCode,
    status,
    estimatedArrival,
    serverSeq: this.getLatestSeq(),
  };
}
```

### 1.7 `applyMutationsBatch` Extension (`library_track`, `playlist`, `track`)
Inside `VhunambiDatabase.applyMutationsBatch()` (`vhunambi_db.ts:363`), we add domain handlers for `library_track`, `playlist`, and `track` so outbox mutations flushed via `POST /api/v1/sync/batch` immediately materialize in the respective SQLite tables:

```typescript
// Inside VhunambiDatabase.applyMutationsBatch() switch/if chain:
} else if (m.entityType === 'library_track') {
  const creatorId = String(m.payload.creatorId ?? 'usr_me');
  if (m.operation === 'purge') {
    this.db
      .prepare('DELETE FROM user_library_sync WHERE id = ? AND creator_id = ?')
      .run(m.entityId, creatorId);
  } else {
    const title = String(m.payload.title ?? 'Library Track');
    const itemType = Boolean(m.payload.isStem) ? 'stem' : 'track';
    this.db
      .prepare(
        `INSERT INTO user_library_sync (id, creator_id, item_type, title, data_json, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           title = excluded.title,
           data_json = excluded.data_json,
           updated_at = excluded.updated_at`
      )
      .run(m.entityId, creatorId, itemType, title, JSON.stringify(m.payload), now, now);
  }
} else if (m.entityType === 'playlist') {
  if (m.operation === 'delete') {
    this.db.prepare('DELETE FROM playlists WHERE id = ?').run(m.entityId);
  } else {
    const creatorId = String(m.payload.creator_id ?? m.payload.creatorId ?? 'usr_me');
    const title = String(m.payload.title ?? 'Untitled Playlist');
    const description = String(m.payload.description ?? '');
    const coverImageUrl = m.payload.cover_image_url ? String(m.payload.cover_image_url) : null;
    const trackIds = Array.isArray(m.payload.track_ids) ? m.payload.track_ids : [];
    const isPublic = Boolean(m.payload.is_public) ? 1 : 0;
    this.db
      .prepare(
        `INSERT INTO playlists (
          id, creator_id, title, description, cover_image_url, track_ids_json,
          is_public, share_code, share_url, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          description = excluded.description,
          cover_image_url = excluded.cover_image_url,
          track_ids_json = excluded.track_ids_json,
          is_public = excluded.is_public,
          updated_at = excluded.updated_at`
      )
      .run(
        m.entityId,
        creatorId,
        title,
        description,
        coverImageUrl,
        JSON.stringify(trackIds),
        isPublic,
        m.payload.share_code ? String(m.payload.share_code) : null,
        m.payload.share_url ? String(m.payload.share_url) : null,
        now,
        now
      );
  }
} else if (m.entityType === 'track') {
  this.upsertExploreTrack({ ...m.payload, id: m.entityId });
}
```

---

## 2. Backend Hono Route Implementations (`apps/vhunambi_api/src/routes/*.ts`)

### 2.1 Explore Routes (`apps/vhunambi_api/src/routes/explore_routes.ts`)

```typescript
import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const exploreRoutes = new Hono();

/**
 * GET /api/explore
 * Unified discovery endpoint returning tracks, kinetic posts, creators, and genre radio stations.
 */
exploreRoutes.get('/', (c) => {
  const genre = c.req.query('genre');
  const stage = c.req.query('stage');
  const sort = (c.req.query('sort') as 'trending' | 'newest' | 'likes' | 'plays' | undefined) ?? 'trending';
  const search = c.req.query('search');
  const cursor = c.req.query('cursor');
  const limitRaw = c.req.query('limit');
  const limit = limitRaw ? parseInt(limitRaw, 10) : 30;

  const tracksResult = vhunambiDb.getExploreTracks({
    genre,
    stage,
    sort,
    search,
    limit,
  });

  const feedResult = vhunambiDb.getExploreFeed({
    genre,
    cursor,
    limit,
  });

  const creators = vhunambiDb.getAllCreators();
  const activeGenre = genre && genre.toLowerCase() !== 'all' ? genre : 'Amapiano';
  const featuredRadio = vhunambiDb.getExploreRadioRotation(activeGenre, 12);

  return c.json({
    status: 'ok',
    data: {
      tracks: tracksResult.items,
      totalTracks: tracksResult.total,
      posts: feedResult.items,
      creators,
      featuredRadio,
      nextCursor: feedResult.nextCursor,
      hasMore: feedResult.hasMore,
      serverSeq: tracksResult.serverSeq,
    },
  });
});

/**
 * GET /api/explore/tracks
 * Dedicated African genre track catalog endpoint.
 */
exploreRoutes.get('/tracks', (c) => {
  const genre = c.req.query('genre');
  const stage = c.req.query('stage');
  const sort = (c.req.query('sort') as 'trending' | 'newest' | 'likes' | 'plays' | undefined) ?? 'trending';
  const search = c.req.query('search');
  const limitRaw = c.req.query('limit');
  const limit = limitRaw ? parseInt(limitRaw, 10) : 50;

  const result = vhunambiDb.getExploreTracks({ genre, stage, sort, search, limit });
  return c.json({
    status: 'ok',
    data: result,
  });
});

/**
 * POST /api/explore/tracks
 * Publish or update a track in the Explore discovery catalog.
 */
exploreRoutes.post('/tracks', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  if (!body.title) {
    return c.json({ error: 'title is required' }, 400);
  }
  const track = vhunambiDb.upsertExploreTrack(body);
  return c.json(
    {
      status: 'ok',
      data: track,
      serverSeq: vhunambiDb.getLatestSeq(),
    },
    201
  );
});

/**
 * GET /api/explore/radio/:genre
 * Dynamic harmonic radio rotation for any African genre.
 */
exploreRoutes.get('/radio/:genre', (c) => {
  const genre = c.req.param('genre') || 'All';
  const limitRaw = c.req.query('limit');
  const limit = limitRaw ? parseInt(limitRaw, 10) : 20;
  const radio = vhunambiDb.getExploreRadioRotation(genre, limit);
  return c.json({
    status: 'ok',
    data: radio,
  });
});

/**
 * GET /api/explore/feed
 * Paginated Kinetic Reels & Explore Feed with cursor pagination.
 */
exploreRoutes.get('/feed', (c) => {
  const genre = c.req.query('genre');
  const cursor = c.req.query('cursor');
  const limitRaw = c.req.query('limit');
  const limit = limitRaw ? parseInt(limitRaw, 10) : 20;

  const feed = vhunambiDb.getExploreFeed({ genre, cursor, limit });
  return c.json({
    status: 'ok',
    data: feed,
  });
});

/**
 * POST /api/explore/posts/:id/cosign
 */
exploreRoutes.post('/posts/:id/cosign', async (c) => {
  const postId = c.req.param('id');
  const body = await c.req.json().catch(() => ({}));
  const fromCreatorId = body.fromCreatorId || 'usr_me';

  const result = vhunambiDb.cosignPost(postId, fromCreatorId);
  return c.json({
    status: 'ok',
    data: result,
  });
});

/**
 * POST /api/explore/posts/:id/repost
 */
exploreRoutes.post('/posts/:id/repost', async (c) => {
  const postId = c.req.param('id');
  const body = await c.req.json().catch(() => ({}));
  const fromCreatorId = body.fromCreatorId || 'usr_me';

  const result = vhunambiDb.repostPost(postId, fromCreatorId);
  return c.json({
    status: 'ok',
    data: result,
  });
});
```

### 2.2 Library Sync Routes (`apps/vhunambi_api/src/routes/library_routes.ts`)

```typescript
import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const libraryRoutes = new Hono();

/**
 * GET /api/library
 */
libraryRoutes.get('/', (c) => {
  const creatorId = c.req.query('creatorId') || 'usr_me';
  const items = vhunambiDb.getLibraryItems(creatorId);
  return c.json({
    status: 'ok',
    data: {
      creatorId,
      count: items.length,
      items,
      serverSeq: vhunambiDb.getLatestSeq(),
    },
  });
});

/**
 * GET /api/library/sync
 * Pull cloud library state and current serverSeq for delta reconciliation.
 */
libraryRoutes.get('/sync', (c) => {
  const creatorId = c.req.query('creatorId') || 'usr_me';
  const items = vhunambiDb.getLibraryItems(creatorId);
  return c.json({
    status: 'ok',
    data: {
      creatorId,
      count: items.length,
      items,
      serverSeq: vhunambiDb.getLatestSeq(),
      syncedAt: new Date().toISOString(),
    },
  });
});

/**
 * POST /api/library/sync
 * Bi-directional cloud delta sync between local Hive Library and SQLite WAL.
 */
libraryRoutes.post('/sync', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const creatorId = typeof body.creatorId === 'string' ? body.creatorId : 'usr_me';
  const items = Array.isArray(body.items) ? body.items : [];
  const deletedIds = Array.isArray(body.deletedIds) ? body.deletedIds : [];

  const result = vhunambiDb.syncLibraryDelta({
    creatorId,
    items,
    deletedIds,
  });

  return c.json({
    status: 'ok',
    data: result,
  });
});

/**
 * POST /api/library
 * Upsert a single library item.
 */
libraryRoutes.post('/', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  if (!body.title) {
    return c.json({ error: 'title is required' }, 400);
  }
  const item = vhunambiDb.upsertLibraryItem({
    id: body.id,
    creatorId: body.creatorId || 'usr_me',
    itemType: body.itemType || 'track',
    title: body.title,
    data: body.data || body,
  });
  return c.json({ status: 'ok', data: item }, 201);
});

/**
 * DELETE /api/library/:id
 */
libraryRoutes.delete('/:id', (c) => {
  const id = c.req.param('id');
  const creatorId = c.req.query('creatorId') || 'usr_me';
  const deleted = vhunambiDb.deleteLibraryItem(id, creatorId);
  if (!deleted) {
    return c.json({ error: 'Library item not found' }, 404);
  }
  return c.json({ status: 'ok', deletedId: id, serverSeq: vhunambiDb.getLatestSeq() });
});
```

### 2.3 Playlists Routes (`apps/vhunambi_api/src/routes/playlist_routes.ts` — New File)

```typescript
import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const playlistRoutes = new Hono();

/**
 * GET /api/playlists
 */
playlistRoutes.get('/', (c) => {
  const creatorId = c.req.query('creatorId') || 'usr_me';
  const includePublic = c.req.query('includePublic') !== 'false';
  const items = vhunambiDb.getPlaylists(creatorId, includePublic);
  return c.json({
    status: 'ok',
    data: {
      items,
      total: items.length,
      serverSeq: vhunambiDb.getLatestSeq(),
    },
  });
});

/**
 * GET /api/playlists/:id
 */
playlistRoutes.get('/:id', (c) => {
  const id = c.req.param('id');
  const playlist = vhunambiDb.getPlaylistById(id);
  if (!playlist) {
    return c.json({ error: `Playlist ${id} not found` }, 404);
  }
  return c.json({
    status: 'ok',
    data: playlist,
  });
});

/**
 * POST /api/playlists
 */
playlistRoutes.post('/', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const title = typeof body.title === 'string' ? body.title.trim() : '';
  if (!title) {
    return c.json({ error: 'Playlist title is required' }, 400);
  }

  const playlist = vhunambiDb.upsertPlaylist({
    id: body.id,
    creatorId: body.creator_id || body.creatorId || 'usr_me',
    title,
    description: body.description ?? '',
    coverImageUrl: body.cover_image_url ?? body.coverImageUrl ?? null,
    trackIds: Array.isArray(body.track_ids)
      ? body.track_ids
      : Array.isArray(body.trackIds)
      ? body.trackIds
      : [],
    isPublic: Boolean(body.is_public ?? body.isPublic ?? false),
    shareCode: body.share_code ?? body.shareCode ?? null,
    shareUrl: body.share_url ?? body.shareUrl ?? null,
  });

  return c.json(
    {
      status: 'ok',
      data: playlist,
      serverSeq: vhunambiDb.getLatestSeq(),
    },
    201
  );
});

/**
 * PUT /api/playlists/:id
 */
playlistRoutes.put('/:id', async (c) => {
  const id = c.req.param('id');
  const existing = vhunambiDb.getPlaylistById(id);
  const body = await c.req.json().catch(() => ({}));

  const title =
    typeof body.title === 'string' && body.title.trim().length > 0
      ? body.title.trim()
      : existing?.title ?? 'Untitled Playlist';

  const updated = vhunambiDb.upsertPlaylist({
    id,
    creatorId: body.creator_id ?? body.creatorId ?? existing?.creator_id ?? 'usr_me',
    title,
    description: body.description ?? existing?.description ?? '',
    coverImageUrl:
      body.cover_image_url !== undefined
        ? body.cover_image_url
        : body.coverImageUrl !== undefined
        ? body.coverImageUrl
        : existing?.cover_image_url ?? null,
    trackIds: Array.isArray(body.track_ids)
      ? body.track_ids
      : Array.isArray(body.trackIds)
      ? body.trackIds
      : existing?.track_ids ?? [],
    isPublic:
      body.is_public !== undefined
        ? Boolean(body.is_public)
        : body.isPublic !== undefined
        ? Boolean(body.isPublic)
        : existing?.is_public ?? false,
  });

  return c.json({
    status: 'ok',
    data: updated,
    serverSeq: vhunambiDb.getLatestSeq(),
  });
});

/**
 * DELETE /api/playlists/:id
 */
playlistRoutes.delete('/:id', (c) => {
  const id = c.req.param('id');
  const deleted = vhunambiDb.deletePlaylist(id);
  if (!deleted) {
    return c.json({ error: `Playlist ${id} not found` }, 404);
  }
  return c.json({
    status: 'ok',
    deletedId: id,
    serverSeq: vhunambiDb.getLatestSeq(),
  });
});

/**
 * POST /api/playlists/:id/share
 */
playlistRoutes.post('/:id/share', (c) => {
  const id = c.req.param('id');
  try {
    const shared = vhunambiDb.sharePlaylist(id);
    return c.json({
      status: 'ok',
      data: {
        playlistId: shared.playlist.id,
        shareCode: shared.shareCode,
        shareUrl: shared.shareUrl,
        isPublic: true,
        sharedAt: shared.sharedAt,
        playlist: shared.playlist,
      },
      serverSeq: vhunambiDb.getLatestSeq(),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Playlist share failed';
    return c.json({ error: message }, 404);
  }
});
```

### 2.4 Wallet Routes & Unified Social Payout Alias (`wallet_routes.ts` & `social_routes.ts`)
In `apps/vhunambi_api/src/routes/wallet_routes.ts`, we add `GET /banks` and pass `branchCode`, `paymentRail`, and `accountHolder` to `vhunambiDb.requestPayout`:

```typescript
// apps/vhunambi_api/src/routes/wallet_routes.ts
import { Hono } from 'hono';
import { SA_BANK_REGISTRY, vhunambiDb } from '../db/vhunambi_db.js';

export const walletRoutes = new Hono();

/**
 * GET /api/wallet/banks
 * Returns canonical South African banks and supported payout gateway rails.
 */
walletRoutes.get('/banks', (c) => {
  const uniqueBanks = Array.from(
    new Map(
      Object.values(SA_BANK_REGISTRY).map((b) => [b.code, b])
    ).values()
  );
  return c.json({
    status: 'ok',
    data: {
      banks: uniqueBanks,
      rails: [
        { id: 'capitec_pay', label: 'Capitec Pay Instant RTC', feeZar: 2.5, eta: '< 60 sec' },
        { id: 'ozow', label: 'Ozow Instant EFT', feeZar: 3.5, eta: '< 2 min' },
        { id: 'payfast', label: 'PayFast Instant Clearing', feeZar: 5.0, eta: '< 4 hrs' },
        { id: 'eft', label: 'Standard SARB EFT', feeZar: 0.0, eta: '1-2 business days' },
      ],
    },
  });
});

/**
 * GET /api/wallet/:creatorId
 */
walletRoutes.get('/:creatorId', (c) => {
  const creatorId = c.req.param('creatorId');
  try {
    const summary = vhunambiDb.getWalletSummary(creatorId);
    return c.json({ status: 'ok', data: summary });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Creator not found';
    return c.json({ error: message }, 404);
  }
});

/**
 * POST /api/wallet/credit
 */
walletRoutes.post('/credit', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  if (!body.creatorId || typeof body.amountZar !== 'number') {
    return c.json({ error: 'creatorId and numeric amountZar are required' }, 400);
  }
  try {
    const result = vhunambiDb.creditWallet({
      creatorId: body.creatorId,
      amountZar: body.amountZar,
      txType: body.txType || 'topup',
      description: body.description || 'Wallet Credit',
      referenceId: body.referenceId,
    });
    return c.json({ status: 'ok', data: result }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Credit failed';
    return c.json({ error: message }, 400);
  }
});

/**
 * POST /api/wallet/payout
 * South African EFT / Capitec Pay / Ozow / PayFast Payout Execution.
 */
walletRoutes.post('/payout', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const creatorId = body.creatorId || 'usr_me';
  if (typeof body.amountZar !== 'number' || !body.bankName || !body.accountNumber) {
    return c.json(
      { error: 'creatorId, amountZar, bankName, and accountNumber are required' },
      400
    );
  }

  try {
    const result = vhunambiDb.requestPayout({
      creatorId,
      amountZar: body.amountZar,
      bankName: body.bankName,
      accountNumber: body.accountNumber,
      branchCode: body.branchCode,
      paymentRail: body.paymentRail,
      accountHolder: body.accountHolder,
    });
    return c.json({ status: 'ok', data: result }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Payout failed';
    return c.json({ error: message }, 400);
  }
});
```

And in `apps/vhunambi_api/src/routes/social_routes.ts` (`POST /creators/:id/wallet/payout`), we bridge directly to `vhunambiDb.requestPayout` when `bankName` and `accountNumber` are provided (or use default saved SA bank details if omitted for legacy callers) so both endpoints stay converged.

### 2.5 Mounting `/api/playlists` in `apps/vhunambi_api/src/server.ts`
In `apps/vhunambi_api/src/server.ts`, import `playlistRoutes` and mount `app.route('/api/playlists', playlistRoutes);`.

---

## 3. Flutter Client Serialization & Hybrid Repositories (`apps/vhunambi_client`)

### 3.1 `Track` JSON Serialization (`lib/shared/models/track.dart`)
We add `copyWith()`, `toJson()`, and `factory Track.fromJson(Map<String, dynamic> json)` to `Track` (`apps/vhunambi_client/lib/shared/models/track.dart`):

```dart
// Additions to Track in apps/vhunambi_client/lib/shared/models/track.dart

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    double? bpm,
    String? key,
    String? genre,
    Duration? duration,
    String? audioUrl,
    String? coverUrl,
    List<double>? waveform,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? cosignsCount,
    int? playCount,
    DateTime? uploadedAt,
    DiscoveryStage? discoveryStage,
    bool? stemsAvailable,
    String? creatorHandle,
    String? province,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      bpm: bpm ?? this.bpm,
      key: key ?? this.key,
      genre: genre ?? this.genre,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      waveform: waveform ?? this.waveform,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      cosignsCount: cosignsCount ?? this.cosignsCount,
      playCount: playCount ?? this.playCount,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      discoveryStage: discoveryStage ?? this.discoveryStage,
      stemsAvailable: stemsAvailable ?? this.stemsAvailable,
      creatorHandle: creatorHandle ?? this.creatorHandle,
      province: province ?? this.province,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'bpm': bpm,
      'musicalKey': key,
      'key': key,
      'genre': genre,
      'durationMs': duration.inMilliseconds,
      'audioUrl': audioUrl,
      'coverUrl': coverUrl,
      'waveform': waveform,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'cosignsCount': cosignsCount,
      'playsCount': playCount,
      'playCount': playCount,
      'createdAt': uploadedAt?.toIso8601String(),
      'discoveryStage': discoveryStage.name,
      'stemsAvailable': stemsAvailable,
      'creatorHandle': creatorHandle,
      'province': province,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final stageRaw = (json['discoveryStage'] ?? json['discovery_stage'] ?? 'freshCrate').toString();
    DiscoveryStage parsedStage = DiscoveryStage.freshCrate;
    for (final stage in DiscoveryStage.values) {
      if (stage.name.toLowerCase() == stageRaw.toLowerCase()) {
        parsedStage = stage;
        break;
      }
    }

    final durationMs = (json['durationMs'] as num?)?.toInt() ??
        (json['duration_ms'] as num?)?.toInt() ??
        180000;

    final rawWaveform = json['waveform'];
    final List<double> parsedWaveform = rawWaveform is List
        ? rawWaveform.map((e) => (e as num).toDouble()).toList()
        : const [0.35, 0.62, 0.84, 0.51, 0.78, 0.92, 0.64, 0.45];

    final createdStr = (json['createdAt'] ?? json['created_at'] ?? json['uploadedAt'])?.toString();

    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Track').toString(),
      artist: (json['artist'] ?? 'Unknown Artist').toString(),
      bpm: (json['bpm'] as num?)?.toDouble() ?? 113.0,
      key: (json['musicalKey'] ?? json['musical_key'] ?? json['key'] ?? 'Am').toString(),
      genre: (json['genre'] ?? 'Amapiano').toString(),
      duration: Duration(milliseconds: durationMs),
      audioUrl: (json['audioUrl'] ?? json['audio_url'])?.toString(),
      coverUrl: (json['coverUrl'] ?? json['cover_url'])?.toString(),
      waveform: parsedWaveform,
      likesCount: (json['likesCount'] as num?)?.toInt() ??
          (json['likes_count'] as num?)?.toInt() ??
          0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ??
          (json['comments_count'] as num?)?.toInt() ??
          0,
      sharesCount: (json['sharesCount'] as num?)?.toInt() ??
          (json['shares_count'] as num?)?.toInt() ??
          0,
      cosignsCount: (json['cosignsCount'] as num?)?.toInt() ??
          (json['cosigns_count'] as num?)?.toInt() ??
          0,
      playCount: (json['playCount'] as num?)?.toInt() ??
          (json['playsCount'] as num?)?.toInt() ??
          (json['plays_count'] as num?)?.toInt() ??
          0,
      uploadedAt: createdStr != null ? DateTime.tryParse(createdStr) : null,
      discoveryStage: parsedStage,
      stemsAvailable: json['stemsAvailable'] == true ||
          json['stems_available'] == true ||
          json['stems_available'] == 1,
      creatorHandle: (json['creatorHandle'] ?? json['creator_handle'])?.toString(),
      province: (json['province'] ?? 'Gauteng').toString(),
    );
  }
```

### 3.2 `HttpExploreRepository` (`lib/features/explore/data/repositories/http_explore_repository.dart`)

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/features/explore/domain/models/explore_models.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class GenreRadioStation {
  final String genre;
  final String stationTitle;
  final String description;
  final double seedBpm;
  final List<Track> rotation;
  final int serverSeq;

  const GenreRadioStation({
    required this.genre,
    required this.stationTitle,
    required this.description,
    required this.seedBpm,
    required this.rotation,
    this.serverSeq = 0,
  });

  factory GenreRadioStation.fromJson(Map<String, dynamic> json) {
    final rawRotation = json['rotation'] as List<dynamic>? ?? const [];
    return GenreRadioStation(
      genre: (json['genre'] ?? 'All').toString(),
      stationTitle: (json['stationTitle'] ?? 'Sovereign Radio').toString(),
      description: (json['description'] ?? '').toString(),
      seedBpm: (json['seedBpm'] as num?)?.toDouble() ?? 113.0,
      rotation: rawRotation
          .whereType<Map>()
          .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      serverSeq: (json['serverSeq'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExploreCloudBundle {
  final List<Track> tracks;
  final List<SocialFeedPost> posts;
  final GenreRadioStation? featuredRadio;
  final int serverSeq;

  const ExploreCloudBundle({
    required this.tracks,
    required this.posts,
    this.featuredRadio,
    this.serverSeq = 0,
  });
}

class HttpExploreRepository {
  final Dio _dio;

  HttpExploreRepository({required Dio dio}) : _dio = dio;

  Future<ExploreCloudBundle> fetchExploreBundle({
    String? genre,
    String? stage,
    String sort = 'trending',
    String? search,
    int limit = 30,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/explore',
      queryParameters: {
        if (genre != null && genre.isNotEmpty && genre != 'All') 'genre': genre,
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        'sort': sort,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
      },
    );

    final data = (response.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawTracks = data['tracks'] as List<dynamic>? ?? const [];
    final rawPosts = data['posts'] as List<dynamic>? ?? const [];
    final rawRadio = data['featuredRadio'] as Map?;

    final tracks = rawTracks
        .whereType<Map>()
        .map((m) => Track.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final posts = rawPosts
        .whereType<Map>()
        .map((m) => _mapPostFromJson(Map<String, dynamic>.from(m)))
        .toList();

    return ExploreCloudBundle(
      tracks: tracks,
      posts: posts,
      featuredRadio: rawRadio != null
          ? GenreRadioStation.fromJson(Map<String, dynamic>.from(rawRadio))
          : null,
      serverSeq: (data['serverSeq'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Track>> fetchExploreTracks({
    String? genre,
    String? stage,
    String sort = 'trending',
    String? search,
    int limit = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/explore/tracks',
      queryParameters: {
        if (genre != null && genre.isNotEmpty && genre != 'All') 'genre': genre,
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        'sort': sort,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
      },
    );
    final data = (response.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((m) => Track.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<GenreRadioStation> fetchGenreRadio(String genre, {int limit = 20}) async {
    final targetGenre = genre.trim().isEmpty ? 'All' : genre.trim();
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/explore/radio/${Uri.encodeComponent(targetGenre)}',
      queryParameters: {'limit': limit},
    );
    final data = (response.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GenreRadioStation.fromJson(data);
  }

  Future<Track> publishTrack(Track track) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/explore/tracks',
      data: track.toJson(),
    );
    final data = (response.data?['data'] as Map?)?.cast<String, dynamic>() ?? track.toJson();
    return Track.fromJson(data);
  }

  SocialFeedPost _mapPostFromJson(Map<String, dynamic> m) {
    final createdAtStr = (m['created_at'] ?? m['createdAt'])?.toString();
    return SocialFeedPost(
      id: (m['id'] ?? '').toString(),
      creatorId: (m['creator_id'] ?? m['creatorId'] ?? 'usr_me').toString(),
      creatorName: (m['creator_name'] ?? m['creatorName'] ?? 'Creator').toString(),
      creatorHandle: (m['creator_handle'] ?? m['creatorHandle'] ?? '@creator').toString(),
      creatorGenre: (m['genre'] ?? 'Amapiano').toString(),
      type: SocialPostType.trackDrop,
      caption: (m['caption'] ?? '').toString(),
      trackId: m['track_id']?.toString() ?? m['id']?.toString(),
      trackTitle: (m['track_title'] ?? m['trackTitle'] ?? 'Untitled').toString(),
      trackBpm: (m['bpm'] as num?)?.toDouble() ?? 113.0,
      trackKey: (m['musical_key'] ?? m['trackKey'] ?? 'Am').toString(),
      likesCount: (m['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (m['comments_count'] as num?)?.toInt() ?? 0,
      repostsCount: (m['reposts_count'] as num?)?.toInt() ?? 0,
      cosignsCount: (m['cosigns_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAtStr != null
          ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

final httpExploreRepositoryProvider = Provider<HttpExploreRepository>((ref) {
  final dio = ref.watch(syncDioProvider);
  return HttpExploreRepository(dio: dio);
});
```

### 3.3 `LibraryTrack` JSON Serialization & `HttpLibrarySyncRepository`
In `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart`, we add `updatedAtMs`, `toJson()`, and `factory LibraryTrack.fromJson(Map<String, dynamic> json)` to `LibraryTrack`:

```dart
// Additions to LibraryTrack in apps/vhunambi_client/lib/features/library/domain/models/library_models.dart

  final int updatedAtMs;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'bpm': bpm,
      'key': key,
      'genre': genre,
      'durationMs': duration.inMilliseconds,
      'dateAdded': dateAdded.toIso8601String(),
      'filePath': filePath,
      'isStem': isStem,
      'isFavorite': isFavorite,
      'playCount': playCount,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'isMastered': isMastered,
      'lufs': lufs,
      'licensePurchaseId': licensePurchaseId,
      'licenseTierId': licenseTierId,
      'licenseCertificateHash': licenseCertificateHash,
      'producerHandle': producerHandle,
      'stemFilePaths': stemFilePaths,
      'updatedAtMs': updatedAtMs,
    };
  }

  factory LibraryTrack.fromJson(Map<String, dynamic> json) {
    final nested = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final durationMs = (nested['durationMs'] as num?)?.toInt() ??
        (nested['duration_ms'] as num?)?.toInt() ??
        180000;
    final dateAddedRaw = (nested['dateAdded'] ?? json['created_at'])?.toString();
    final deletedAtRaw = nested['deletedAt']?.toString();
    final rawStems = nested['stemFilePaths'];

    return LibraryTrack(
      id: (nested['id'] ?? json['id'] ?? '').toString(),
      title: (nested['title'] ?? json['title'] ?? 'Untitled Track').toString(),
      artist: (nested['artist'] ?? 'Sovereign Producer').toString(),
      bpm: (nested['bpm'] as num?)?.toDouble() ?? 113.0,
      key: (nested['key'] ?? nested['musicalKey'] ?? 'Am').toString(),
      genre: (nested['genre'] ?? 'Amapiano').toString(),
      duration: Duration(milliseconds: durationMs),
      dateAdded: dateAddedRaw != null
          ? (DateTime.tryParse(dateAddedRaw) ?? DateTime.now())
          : DateTime.now(),
      filePath: nested['filePath']?.toString(),
      isStem: nested['isStem'] == true || json['item_type'] == 'stem',
      isFavorite: nested['isFavorite'] == true,
      playCount: (nested['playCount'] as num?)?.toInt() ?? 0,
      isDeleted: nested['isDeleted'] == true,
      deletedAt: deletedAtRaw != null ? DateTime.tryParse(deletedAtRaw) : null,
      isMastered: nested['isMastered'] == true,
      lufs: (nested['lufs'] as num?)?.toDouble(),
      licensePurchaseId: nested['licensePurchaseId']?.toString(),
      licenseTierId: nested['licenseTierId']?.toString(),
      licenseCertificateHash: nested['licenseCertificateHash']?.toString(),
      producerHandle: nested['producerHandle']?.toString(),
      stemFilePaths: rawStems is List
          ? rawStems.map((e) => e.toString()).toList()
          : const [],
      updatedAtMs: (nested['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
```

Next, we create `apps/vhunambi_client/lib/features/library/data/repositories/http_library_sync_repository.dart`:

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';

class LibraryCloudSyncStatus {
  final bool isSyncing;
  final int serverSeq;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const LibraryCloudSyncStatus({
    this.isSyncing = false,
    this.serverSeq = 0,
    this.lastSyncedAt,
    this.errorMessage,
  });

  LibraryCloudSyncStatus copyWith({
    bool? isSyncing,
    int? serverSeq,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryCloudSyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      serverSeq: serverSeq ?? this.serverSeq,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LibrarySyncResult {
  final List<LibraryTrack> tracks;
  final int serverSeq;
  final DateTime syncedAt;

  const LibrarySyncResult({
    required this.tracks,
    required this.serverSeq,
    required this.syncedAt,
  });
}

class HttpLibrarySyncRepository {
  static const String boxName = 'vhunambi_library_tracks_v1';
  static final Map<String, String> _memoryFallback = {};

  final Dio _dio;
  final String creatorId;
  Box<String>? _box;

  HttpLibrarySyncRepository({
    required Dio dio,
    this.creatorId = 'usr_me',
  }) : _dio = dio;

  Future<Box<String>?> _getBox() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<String>(boxName);
        return _box;
      }
      _box = await Hive.openBox<String>(boxName);
      return _box;
    } catch (_) {
      return null;
    }
  }

  Future<List<LibraryTrack>> loadLocalTracks() async {
    final box = await _getBox();
    final rawValues = box != null ? box.values.toList() : _memoryFallback.values.toList();
    final tracks = <LibraryTrack>[];
    for (final raw in rawValues) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        tracks.add(LibraryTrack.fromJson(decoded));
      } catch (_) {}
    }
    return tracks;
  }

  Future<void> saveLocalTrack(LibraryTrack track) async {
    final encoded = jsonEncode(track.toJson());
    final box = await _getBox();
    if (box != null) {
      await box.put(track.id, encoded);
    } else {
      _memoryFallback[track.id] = encoded;
    }
  }

  Future<void> saveAllLocalTracks(List<LibraryTrack> tracks) async {
    final box = await _getBox();
    if (box != null) {
      final map = {for (final t in tracks) t.id: jsonEncode(t.toJson())};
      await box.putAll(map);
    } else {
      for (final t in tracks) {
        _memoryFallback[t.id] = jsonEncode(t.toJson());
      }
    }
  }

  Future<void> removeLocalTrack(String id) async {
    final box = await _getBox();
    if (box != null) {
      await box.delete(id);
    } else {
      _memoryFallback.remove(id);
    }
  }

  /// Performs LWW merge between local and remote tracks, preserving license metadata & max playCount.
  List<LibraryTrack> mergeTracksLww(
    List<LibraryTrack> localTracks,
    List<LibraryTrack> remoteTracks,
  ) {
    final mergedMap = <String, LibraryTrack>{
      for (final local in localTracks) local.id: local,
    };

    for (final remote in remoteTracks) {
      final existing = mergedMap[remote.id];
      if (existing == null) {
        mergedMap[remote.id] = remote;
        continue;
      }

      final remoteWins = remote.updatedAtMs >= existing.updatedAtMs;
      final winner = remoteWins ? remote : existing;
      final loser = remoteWins ? existing : remote;

      mergedMap[remote.id] = winner.copyWith(
        playCount: existing.playCount > remote.playCount
            ? existing.playCount
            : remote.playCount,
        licensePurchaseId: winner.licensePurchaseId ?? loser.licensePurchaseId,
        licenseTierId: winner.licenseTierId ?? loser.licenseTierId,
        licenseCertificateHash:
            winner.licenseCertificateHash ?? loser.licenseCertificateHash,
        producerHandle: winner.producerHandle ?? loser.producerHandle,
        stemFilePaths: winner.stemFilePaths.isNotEmpty
            ? winner.stemFilePaths
            : loser.stemFilePaths,
        updatedAtMs: existing.updatedAtMs > remote.updatedAtMs
            ? existing.updatedAtMs
            : remote.updatedAtMs,
      );
    }

    final result = mergedMap.values.toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return result;
  }

  Future<LibrarySyncResult> syncDelta({
    required List<LibraryTrack> localTracks,
    List<String> purgedIds = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/library/sync',
      data: {
        'creatorId': creatorId,
        'items': localTracks.map((t) => t.toJson()).toList(),
        if (purgedIds.isNotEmpty) 'deletedIds': purgedIds,
      },
    );

    final data = (response.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final remoteTracks = rawItems
        .whereType<Map>()
        .map((m) => LibraryTrack.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final merged = mergeTracksLww(localTracks, remoteTracks);
    await saveAllLocalTracks(merged);

    return LibrarySyncResult(
      tracks: merged,
      serverSeq: (data['serverSeq'] as num?)?.toInt() ?? 0,
      syncedAt: DateTime.tryParse((data['syncedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

final httpLibrarySyncRepositoryProvider = Provider<HttpLibrarySyncRepository>((ref) {
  final dio = ref.watch(syncDioProvider);
  return HttpLibrarySyncRepository(dio: dio);
});
```

### 3.4 Playlists Cloud Sync & Sharing (`playlist_entity.dart`, `playlist_repository.dart`, `playlists_provider.dart`)
In `apps/vhunambi_client/lib/features/playlists/domain/models/playlist_entity.dart`, we add optional `shareCode` and `shareUrl`:

```dart
// Updated fields in PlaylistEntity (lib/features/playlists/domain/models/playlist_entity.dart)
  final String? shareCode;
  final String? shareUrl;
```

In `apps/vhunambi_client/lib/features/playlists/data/repositories/playlist_repository.dart`, we add optional `Dio? dio` and `SyncOutboxService? outbox` plus `syncPlaylistsWithCloud()` and `sharePlaylist(String id)`:
- Every `createPlaylist`, `updatePlaylist`, `deletePlaylist`, `addTrackToPlaylist`, `removeTrackFromPlaylist`, and `reorderTracks` call writes immediately to local Hive/memory, enqueues a `playlist` mutation into `SyncOutboxService` (if attached), and performs a non-blocking HTTP write to `/api/playlists` when `Dio` is provided.
- `sharePlaylist(String id)` calls `POST /api/playlists/$id/share` (with deterministic offline fallback `https://vhunambi.za/p/VH-${id.toUpperCase()}` if offline), updates `isPublic: true`, `shareCode`, and `shareUrl` in Hive, and returns the updated `PlaylistEntity`.

### 3.5 South African Banking & Gateway Payout Wiring (`creator_wallet.dart`, `http_social_repository.dart`, `payout_details_sheet.dart`)
1. In `apps/vhunambi_client/lib/features/social/domain/models/creator_wallet.dart`, we add `SaBankOption` & `PayoutGatewayRail` constants plus `PayoutClearanceReceipt`:
   - Canonical banks: `'Capitec Bank'` (`470010`), `'FNB'` (`250655`), `'Standard Bank'` (`051001`), `'Nedbank'` (`198765`), `'Absa Bank'` (`632005`), `'TymeBank'` (`678910`).
   - Gateway rails: `'capitec_pay'` (`Capitec Pay Instant RTC`), `'ozow'` (`Ozow Instant EFT`), `'payfast'` (`PayFast Clearing`), `'eft'` (`Standard SARB EFT`).
2. In `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`, `requestPayout()` calls `POST /api/wallet/payout` with `{ creatorId, amountZar, bankName, accountNumber, branchCode, paymentRail }` and falls back to `POST /api/creators/$creatorId/wallet/payout`, mapping the returned balance and `PayoutClearanceReceipt` transaction into `CreatorWallet`.
3. In `apps/vhunambi_client/lib/features/profile/presentation/widgets/payout_details_sheet.dart`:
   - Selecting any of the 6 SA banks automatically populates its canonical 6-digit universal branch code (`470010`, `250655`, `051001`, `198765`, `632005`, `678910`) in `_branchController`.
   - Adds a 4-pill Settlement Rail selector (`Key('payout_rail_capitec_pay')`, `Key('payout_rail_ozow')`, `Key('payout_rail_payfast')`, `Key('payout_rail_eft')`).

### 3.6 `EdgeSyncCoordinator` Delta Hydrator Dispatch (`lib/core/sync/edge_sync_coordinator.dart`)
In `apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart`, we add:

```dart
typedef SyncDeltaHydrator = FutureOr<void> Function(
  List<Map<String, dynamic>> mutations,
);
```

Inside `EdgeSyncCoordinator`:
- Maintain `final List<SyncDeltaHydrator> _deltaHydrators = [];`
- Expose `void registerDeltaHydrator(SyncDeltaHydrator hydrator)` and `void unregisterDeltaHydrator(SyncDeltaHydrator hydrator)`.
- Inside `syncNow()`, when `changes` (`List<dynamic>`) are returned from `GET /api/v1/sync/delta`, convert each item to `Map<String, dynamic>` and invoke every registered `SyncDeltaHydrator` safely inside a `try / catch` block before updating `SyncCoordinatorState`.

---

## 4. Design-System & Icon Hygiene (`STD-UIUX-001`)
In `apps/vhunambi_client/lib/features/playlists/presentation/views/playlists_vault_view.dart`:
- Replace `Icon(Icons.search_rounded, ...)` (`line 167`) with `PhosphorIcon(PhosphorIcons.magnifyingGlass(), color: AppColors.textMuted, size: 18)`.
- Replace `Icon(Icons.clear_rounded, ...)` (`line 170`) with `PhosphorIcon(PhosphorIcons.x(), color: AppColors.textMuted, size: 16)`.
- Replace `Icon(Icons.add_rounded, ...)` (`line 203`) with `PhosphorIcon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 18, color: AppColors.backgroundPrimary)`.
- Add a Cloud Sync icon button (`Key('playlists_cloud_sync_btn')`) with `PhosphorIcons.cloudArrowUp()` next to the Create Playlist button.

