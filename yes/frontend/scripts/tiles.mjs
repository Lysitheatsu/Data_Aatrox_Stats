/**
 * Local OpenStreetMap tile pipeline for development.
 *
 *   node scripts/tiles.mjs build    generate tiles/elly-melbourne.pmtiles
 *   node scripts/tiles.mjs serve    serve them at http://localhost:8080
 *
 * `build` runs Planetiler, whose default profile emits the **OpenMapTiles
 * schema** — the same schema the production tile server uses — so the style in
 * src/map/style.ts is validated against real layer names before handover.
 *
 * `serve` exposes standard {z}/{x}/{y} URLs, matching the shape of the
 * production tile server, so switching to it is an env var change and nothing
 * else. See MAP_SETUP.md.
 */
import { createWriteStream } from 'node:fs';
import { mkdir, open, readFile, rm, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { gunzipSync, brotliDecompressSync } from 'node:zlib';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import AdmZip from 'adm-zip';
import { Compression, PMTiles } from 'pmtiles';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const TILE_DIR = resolve(ROOT, 'tiles');
const ARCHIVE = resolve(TILE_DIR, 'elly-melbourne.pmtiles');
const ARCHIVE_NAME = 'elly-melbourne';
const PLANETILER_JAR = resolve(TILE_DIR, 'planetiler.jar');
const FONT_DIR = resolve(TILE_DIR, 'fonts');
// Prebuilt SDF glyph PBFs. Labels need these; vector tiles carry the label
// text but no font data. A production tile server serves its own /fonts.
const FONT_URL =
  'https://github.com/openmaptiles/fonts/releases/download/v2.0/noto-sans.zip';
// Must match FONT in src/map/style.ts.
const FONT_STACK = 'Noto Sans Regular';
const PLANETILER_URL =
  'https://github.com/onthegomap/planetiler/releases/latest/download/planetiler.jar';
// Planetiler's --area flag only accepts Geofabrik region names, which are
// country/state sized — there is no "melbourne" region. City extracts come
// from BBBike instead and are passed with --osm_url.
//
// Set ELLY_TILE_AREA to a Geofabrik name (e.g. "australia") to use that
// instead; it is ignored unless ELLY_OSM_URL is empty.
const AREA = process.env.ELLY_TILE_AREA ?? '';
const OSM_URL =
  process.env.ELLY_OSM_URL ??
  (AREA ? '' : 'https://download.bbbike.org/osm/bbbike/Melbourne/Melbourne.osm.pbf');
const PORT = Number(process.env.ELLY_TILE_PORT ?? 8080);

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function download(url, dest) {
  console.log(`downloading ${url}`);
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok) throw new Error(`download failed: ${res.status} ${res.statusText}`);
  const out = createWriteStream(dest);
  const reader = res.body.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    out.write(value);
  }
  await new Promise((r) => out.end(r));
}

/**
 * Planetiler requires Java 21+. Without this check it fails with an opaque
 * UnsupportedClassVersionError / LinkageError.
 */
async function checkJava() {
  const version = await new Promise((res) => {
    const proc = spawn('java', ['-version'], { stdio: ['ignore', 'ignore', 'pipe'] });
    let out = '';
    proc.stderr.on('data', (d) => (out += d));
    proc.on('close', () => res(out));
    proc.on('error', () => res(''));
  });

  const match = /version "(\d+)/.exec(version);
  if (!match) {
    console.error('could not find Java. Planetiler needs Java 21 or later.');
    process.exit(1);
  }
  if (Number(match[1]) < 21) {
    console.error(`Java ${match[1]} found, but Planetiler requires Java 21 or later.`);
    console.error('Install a 21+ JDK (e.g. Temurin) and re-run, or ask a teammate');
    console.error('to generate tiles/elly-melbourne.pmtiles for you.');
    process.exit(1);
  }
}

/**
 * Fetch the glyph pack and keep only the font stack the style uses, so the dev
 * setup does not depend on MapLibre's public demo font server.
 */
async function fetchFonts() {
  if (await exists(resolve(FONT_DIR, FONT_STACK))) {
    console.log(`fonts: ${FONT_STACK} already present`);
    return;
  }

  const zipPath = resolve(TILE_DIR, 'noto-sans.zip');
  if (!(await exists(zipPath))) await download(FONT_URL, zipPath);

  console.log(`extracting "${FONT_STACK}" glyphs`);
  const zip = new AdmZip(zipPath);
  let count = 0;
  for (const entry of zip.getEntries()) {
    // Entries look like "Noto Sans Regular/0-255.pbf". Keep only our stack.
    if (entry.isDirectory || !entry.entryName.includes(`${FONT_STACK}/`)) continue;
    zip.extractEntryTo(entry, FONT_DIR, false, true, false, `${FONT_STACK}/${entry.name}`);
    count += 1;
  }

  if (count === 0) {
    throw new Error(`no glyphs for "${FONT_STACK}" found in ${zipPath}`);
  }
  console.log(`fonts: extracted ${count} glyph ranges`);
  // The 59MB zip is not needed once extracted.
  await rm(zipPath, { force: true });
}

async function build() {
  await checkJava();
  await mkdir(TILE_DIR, { recursive: true });
  await fetchFonts();
  if (!(await exists(PLANETILER_JAR))) {
    await download(PLANETILER_URL, PLANETILER_JAR);
  } else {
    console.log('planetiler.jar already present');
  }

  const source = OSM_URL || `geofabrik:${AREA}`;
  console.log(`building tiles from ${source} -> ${ARCHIVE}`);
  console.log('(first run downloads the OSM extract; this takes a few minutes)');

  // --download fetches the supporting sources (water polygons, natural earth)
  // regardless of where the OSM extract itself comes from.
  const args = [
    '-Xmx2g',
    '-jar',
    PLANETILER_JAR,
    '--download',
    `--output=${ARCHIVE}`,
    '--force',
    // --osm_path is set explicitly: without it the downloaded extract is saved
    // under Planetiler's default name (monaco.osm.pbf), which is confusing.
    ...(OSM_URL
      ? [`--osm_url=${OSM_URL}`, `--osm_path=data/sources/${ARCHIVE_NAME}.osm.pbf`]
      : [`--area=${AREA}`]),
  ];

  const code = await new Promise((res) => {
    const proc = spawn('java', args, { stdio: 'inherit', cwd: TILE_DIR });
    proc.on('close', res);
  });

  if (code !== 0) {
    console.error(`\nplanetiler exited with code ${code}`);
    process.exit(code ?? 1);
  }
  console.log(`\ndone. now run: node scripts/tiles.mjs serve`);
}

/** pmtiles Source backed by a local file handle (the library ships browser-only sources). */
function nodeFileSource(handle, key) {
  return {
    getKey: () => key,
    getBytes: async (offset, length) => {
      const buf = Buffer.alloc(length);
      await handle.read(buf, 0, length, offset);
      return { data: buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
    },
  };
}

const decompress = async (buf, compression) => {
  if (compression === Compression.None || compression === Compression.Unknown) return buf;
  if (compression === Compression.Gzip) return gunzipSync(Buffer.from(buf));
  if (compression === Compression.Brotli) return brotliDecompressSync(Buffer.from(buf));
  throw new Error(`unsupported pmtiles compression: ${compression}`);
};

async function serve() {
  if (!(await exists(ARCHIVE))) {
    console.error(`no tile archive at ${ARCHIVE}`);
    console.error('run: node scripts/tiles.mjs build');
    process.exit(1);
  }

  const handle = await open(ARCHIVE, 'r');
  const archive = new PMTiles(nodeFileSource(handle, ARCHIVE_NAME), undefined, decompress);
  const header = await archive.getHeader();
  console.log(
    `serving ${ARCHIVE_NAME} z${header.minZoom}-${header.maxZoom} on http://localhost:${PORT}`,
  );

  // Matches DEV_TILES in src/map/tileSource.ts.
  const pattern = new RegExp(`^/${ARCHIVE_NAME}/(\\d+)/(\\d+)/(\\d+)\\.(mvt|pbf)$`);

  createServer(async (req, res) => {
    // The Expo dev server runs on a different port, so CORS is required.
    res.setHeader('Access-Control-Allow-Origin', '*');

    if (req.url === '/health') {
      res.writeHead(200).end('ok');
      return;
    }

    // Glyphs for map labels: /fonts/{fontstack}/{range}.pbf
    const font = /^\/fonts\/([^/]+)\/(\d+-\d+)\.pbf$/.exec(req.url ?? '');
    if (font) {
      // MapLibre may request a comma-separated stack; we serve the first one.
      const stack = decodeURIComponent(font[1]).split(',')[0].trim();
      try {
        const glyph = await readFile(resolve(FONT_DIR, stack, `${font[2]}.pbf`));
        res.writeHead(200, {
          'Content-Type': 'application/x-protobuf',
          'Cache-Control': 'max-age=86400',
        });
        res.end(glyph);
      } catch {
        console.error(`missing glyphs for "${stack}" ${font[2]} — run tiles:build`);
        res.writeHead(404).end('glyph not found');
      }
      return;
    }

    const match = pattern.exec(req.url ?? '');
    if (!match) {
      res.writeHead(404).end('not found');
      return;
    }

    const [, z, x, y] = match;
    try {
      const tile = await archive.getZxy(Number(z), Number(x), Number(y));
      if (!tile) {
        // Empty 204 is correct for "no data here", not an error.
        res.writeHead(204).end();
        return;
      }
      res.writeHead(200, {
        'Content-Type': 'application/x-protobuf',
        'Cache-Control': 'max-age=3600',
      });
      res.end(Buffer.from(tile.data));
    } catch (err) {
      console.error(`tile ${z}/${x}/${y} failed:`, err.message);
      res.writeHead(500).end('tile error');
    }
  }).listen(PORT);
}

const command = process.argv[2];
if (command === 'build') await build();
else if (command === 'serve') await serve();
else if (command === 'fonts') {
  await mkdir(TILE_DIR, { recursive: true });
  await fetchFonts();
} else {
  console.error('usage: node scripts/tiles.mjs <build|serve|fonts>');
  process.exit(1);
}
