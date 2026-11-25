#!/usr/bin/env node
/**
 * VHUNAMBI Phase 84 — Zero-Duplication Zania Music Catalog Ingest CLI
 *
 * Scans local ZANIA MUSIC READY/ folders with bounded memory (<150 MB RSS, concurrency=2),
 * deduplicates tracks by content SHA-256 against /api/media/presign-put, uploads MP3s
 * directly to R2 via SigV4 PUT, extracts APIC cover + ID3 tags via /api/media/finalize,
 * and publishes tracks + companion lyrics to POST /api/explore/tracks.
 */
import { createHash } from 'node:crypto';
import { createReadStream, existsSync } from 'node:fs';
import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function resolveGenreFromRelativePath(relPath) {
  const norm = relPath.replace(/\\/g, '/').toLowerCase();
  if (norm.includes('amapiano')) {
    return { genre: 'Amapiano', subGenre: 'Private School Amapiano', moodId: 'groove' };
  }
  if (norm.includes('venda afro')) {
    return { genre: 'Afrobeats', subGenre: 'Venda Afro', moodId: 'soulful' };
  }
  if (norm.startsWith('afro/')) {
    return { genre: 'Afrobeats', subGenre: 'Afro Fusion', moodId: 'uplifting' };
  }
  if (norm.startsWith('house/')) {
    return { genre: 'Afro House', subGenre: 'Deep House', moodId: 'euphoric' };
  }
  if (norm.startsWith('pop/')) {
    return { genre: 'Mzansi Pop', subGenre: 'Afro Pop', moodId: 'uplifting' };
  }
  if (norm.startsWith('rock/')) {
    return { genre: 'Afro Rock', subGenre: 'Alternative Rock', moodId: 'energetic' };
  }
  if (norm.startsWith('wave/')) {
    return { genre: 'Afro Fusion', subGenre: 'Synth Wave', moodId: 'late_night' };
  }
  if (norm.startsWith('instrumental/')) {
    return { genre: 'Instrumental', subGenre: 'Studio Bed', moodId: 'focus' };
  }
  if (norm.startsWith('jazz/')) {
    return { genre: 'Afro Jazz', subGenre: 'Cape Jazz', moodId: 'chill' };
  }
  if (norm.startsWith('phonk/')) {
    return { genre: 'Phonk', subGenre: 'Dark Bounce', moodId: 'intense' };
  }
  if (norm.startsWith('epic orchestration/')) {
    return { genre: 'Cinematic', subGenre: 'Epic Orchestral', moodId: 'cinematic' };
  }
  if (norm.startsWith('trap/')) {
    return { genre: 'SA Hip Hop', subGenre: 'Trap', moodId: 'intense' };
  }
  if (norm.startsWith('celestial/')) {
    return { genre: 'Ambient', subGenre: 'Celestial', moodId: 'peaceful' };
  }
  if (norm.startsWith('rap/')) {
    return { genre: 'SA Hip Hop', subGenre: 'Rap', moodId: 'energetic' };
  }
  return { genre: 'Afro Fusion', subGenre: 'Zania Curated', moodId: 'chill' };
}

export async function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = createHash('sha256');
    const stream = createReadStream(filePath);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
    stream.on('error', reject);
  });
}

export async function collectMp3Files(rootDir, currentDir = rootDir, out = []) {
  const entries = await readdir(currentDir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      await collectMp3Files(rootDir, full, out);
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.mp3')) {
      const dir = path.dirname(full);
      const siblingCover =
        ['cover.webp', 'cover.png', 'cover.jpg']
          .map((c) => path.join(dir, c))
          .find((p) => existsSync(p)) ?? null;
      const siblingLyrics =
        ['lyrics.txt', `${path.basename(full, '.mp3')}.txt`]
          .map((l) => path.join(dir, l))
          .find((p) => existsSync(p)) ?? null;
      const rel = path.relative(rootDir, full);
      const fileStat = await stat(full);
      out.push({
        fullPath: full,
        relativePath: rel,
        filename: entry.name,
        title: entry.name.replace(/\.mp3$/i, '').trim().normalize('NFC'),
        sizeBytes: fileStat.size,
        siblingCover,
        siblingLyrics,
        ...resolveGenreFromRelativePath(rel),
      });
    }
  }
  return out;
}

async function ingestOne(item, { apiUrl, token, creatorId }) {
  const contentSha256 = await sha256File(item.fullPath);
  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  const presignRes = await fetch(`${apiUrl}/api/media/presign-put`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      filename: item.filename,
      mimeType: 'audio/mpeg',
      sizeBytes: item.sizeBytes,
      title: item.title,
      sourceSurface: 'zania_ingest',
      contentSha256,
    }),
  });
  if (!presignRes.ok) {
    throw new Error(
      `presign-put failed (${presignRes.status}): ${await presignRes.text()}`,
    );
  }
  const presign = await presignRes.json();
  let asset = presign.asset;

  if (!presign.deduplicated) {
    const mp3Bytes = await readFile(item.fullPath);
    if (presign.uploadStrategy === 'r2_presigned_put' && presign.putUrl) {
      const putRes = await fetch(presign.putUrl, {
        method: 'PUT',
        headers: { 'Content-Type': 'audio/mpeg' },
        body: mp3Bytes,
      });
      if (!putRes.ok) {
        throw new Error(`R2 PUT failed (${putRes.status})`);
      }

      const finRes = await fetch(`${apiUrl}/api/media/finalize`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
          uploadId: presign.uploadId,
          r2Key: presign.r2Key,
          filename: item.filename,
          mimeType: 'audio/mpeg',
          sizeBytes: item.sizeBytes,
          title: item.title,
          sourceSurface: 'zania_ingest',
          contentSha256,
        }),
      });
      if (!finRes.ok) {
        throw new Error(
          `finalize failed (${finRes.status}): ${await finRes.text()}`,
        );
      }
      asset = (await finRes.json()).asset;
    } else {
      const upRes = await fetch(`${apiUrl}/api/media/upload`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'audio/mpeg',
          'x-media-filename': item.filename,
          'x-media-title': item.title,
          'x-media-surface': 'zania_ingest',
          'x-media-sha256': contentSha256,
        },
        body: mp3Bytes,
      });
      if (!upRes.ok) {
        throw new Error(`upload failed (${upRes.status}): ${await upRes.text()}`);
      }
      asset = (await upRes.json()).asset;
    }
  }

  const lyricsText = (
    item.siblingLyrics
      ? await readFile(item.siblingLyrics, 'utf8')
      : String(asset?.id3Metadata?.lyrics ?? '')
  )
    .trim()
    .normalize('NFC');

  const trackRes = await fetch(`${apiUrl}/api/explore/tracks`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      id: `trk_zania_${contentSha256.slice(0, 14)}`,
      creatorId,
      title: asset?.title || item.title,
      artist: asset?.id3Metadata?.artist || 'Zania Music',
      genre: item.genre,
      subGenre: item.subGenre,
      moodId: item.moodId,
      bpm: asset?.id3Metadata?.bpm || 114,
      audioUrl: asset?.remoteUrl,
      coverUrl: asset?.thumbnailUrl || '',
      contentSha256,
      sourceOrigin: 'creator_upload_zania',
      lyricsText,
    }),
  });
  if (!trackRes.ok) {
    throw new Error(
      `explore/tracks failed (${trackRes.status}): ${await trackRes.text()}`,
    );
  }
  return {
    status: presign.deduplicated ? 'deduped' : 'uploaded',
    title: item.title,
    genre: item.genre,
  };
}

async function main() {
  const args = process.argv.slice(2);
  const getArg = (flag, fallback = '') => {
    const idx = args.indexOf(flag);
    return idx !== -1 && args[idx + 1] ? args[idx + 1] : fallback;
  };
  const dir = getArg('--dir');
  const dryRun = args.includes('--dry-run');
  const apiUrl = getArg(
    '--api-url',
    'https://vhunambi-api.ndugelosigwadi.workers.dev',
  ).replace(/\/+$/, '');
  const token = getArg('--token', process.env.VHUNAMBI_INGEST_TOKEN || '');
  const creatorId = getArg('--creator-id', 'creator_cern');
  const limit = Number.parseInt(getArg('--limit', '0'), 10) || 0;

  if (!dir || !existsSync(dir)) {
    console.error(
      'Error: --dir <path> must point to an existing ZANIA MUSIC directory.',
    );
    process.exit(1);
  }

  const items = await collectMp3Files(dir);
  const subset = limit > 0 ? items.slice(0, limit) : items;

  if (dryRun) {
    const byGenre = {};
    for (const item of subset) {
      byGenre[item.genre] = (byGenre[item.genre] || 0) + 1;
    }
    console.log(
      JSON.stringify(
        {
          dryRun: true,
          scannedMp3s: subset.length,
          withSiblingCover: subset.filter((i) => i.siblingCover).length,
          withSiblingLyrics: subset.filter((i) => i.siblingLyrics).length,
          byGenre,
          sample: subset.slice(0, 5),
        },
        null,
        2,
      ),
    );
    return;
  }

  if (!token) {
    console.error(
      'Error: --token <JWT> or VHUNAMBI_INGEST_TOKEN is required for live ingest.',
    );
    process.exit(1);
  }

  let uploaded = 0;
  let deduped = 0;
  let failed = 0;
  const concurrency = 2;
  let cursor = 0;

  async function worker() {
    while (cursor < subset.length) {
      const item = subset[cursor++];
      try {
        const res = await ingestOne(item, { apiUrl, token, creatorId });
        if (res.status === 'deduped') deduped++;
        else uploaded++;
      } catch (err) {
        failed++;
        console.error(`[FAIL] ${item.relativePath}: ${err.message}`);
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));
  console.log(
    JSON.stringify({ total: subset.length, uploaded, deduped, failed }, null, 2),
  );
  if (failed > 0) process.exit(1);
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
