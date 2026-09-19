/**
 * Where the map gets its tiles from.
 *
 * ELLY Maps renders OpenStreetMap data in the **OpenMapTiles (OMT) schema**.
 * Nothing in the app talks to a specific map vendor: the tile server is chosen
 * entirely by environment variables, exactly like EXPO_PUBLIC_API_URL in
 * `src/api/client.ts`.
 *
 * Deployment is therefore a config change, not a code change — point these at
 * the self-hosted tile server and rebuild.
 *
 * See MAP_SETUP.md for how to run the local dev tile server.
 */

export interface TileSourceConfig {
  /** XYZ template ({z}/{x}/{y}) or a TileJSON endpoint. */
  tilesUrl: string;
  /** Font glyph endpoint: {fontstack}/{range}.pbf. Required for map labels. */
  glyphsUrl: string;
  /** Attribution shown on the map. Required by the ODbL licence. */
  attribution: string;
  /**
   * Tile schema the style is written against. The style in `style.ts` selects
   * OMT layer names (water, transportation, building, place); pointing this at
   * a server using a different schema (Shortbread, Protomaps) renders a blank
   * map even though tiles load fine.
   */
  schema: 'openmaptiles';
}

// ── Tile provider ──────────────────────────────────────────────
// Toggle between local dev tiles and OpenMapTiles.org by swapping
// which block is uncommented.

// --- Local dev (run `npm run tiles:serve` first) ---------------
// const TILES_URL = 'http://localhost:8080/elly-melbourne/{z}/{x}/{y}.mvt';
// const GLYPHS_URL = 'http://localhost:8080/fonts/{fontstack}/{range}.pbf';
// const ATTRIBUTION = '© OpenMapTiles © OpenStreetMap contributors';

// --- OpenMapTiles.org (production) -----------------------------
const TILES_URL = 'https://tiles.openfreemap.org/planet/20260830_080001_pt/{z}/{x}/{y}.pbf';
const GLYPHS_URL = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';
const ATTRIBUTION = '© OpenFreeMap © OpenMapTiles © OpenStreetMap contributors';

export const tileSource: TileSourceConfig = {
  tilesUrl: process.env.EXPO_PUBLIC_MAP_TILES_URL ?? TILES_URL,
  glyphsUrl: process.env.EXPO_PUBLIC_MAP_GLYPHS_URL ?? GLYPHS_URL,
  attribution: process.env.EXPO_PUBLIC_MAP_ATTRIBUTION ?? ATTRIBUTION,
  schema: 'openmaptiles',
};

/** True when the app is still pointed at a localhost dev tile server. */
export function isUsingDevTiles(): boolean {
  return tileSource.tilesUrl.includes('localhost') || tileSource.tilesUrl.includes('127.0.0.1');
}

/**
 * Template for "share my location" links, which are opened by the recipient in
 * a browser rather than rendered by us. Kept here so no screen hardcodes a map
 * provider; point it at an ELLY web map when one exists.
 */
const SHARE_URL_TEMPLATE =
  process.env.EXPO_PUBLIC_MAP_SHARE_URL ?? 'https://www.openstreetmap.org/?mlat={lat}&mlon={lon}';

/** Build a shareable link to a coordinate. */
export function shareLocationUrl(latitude: number, longitude: number): string {
  return SHARE_URL_TEMPLATE.replace('{lat}', String(latitude)).replace('{lon}', String(longitude));
}
