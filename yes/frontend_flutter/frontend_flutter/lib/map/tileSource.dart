/**
 * Where the map gets its tiles from.
 *
 * ELLY Maps renders OpenStreetMap data in the **OpenMapTiles (OMT) schema**.
 * Nothing in the app talks to a specific map vendor: the tile server is chosen
 * entirely by environment variables, exactly like EXPO_PUBLIC_API_URL in
 * `lib/api/client.dart`.
 *
 * Deployment is therefore a config change, not a code change — point these at
 * the self-hosted tile server and rebuild.
 *
 * See MAP_SETUP.md for how to run the local dev tile server.
 */

class TileSourceConfig {
  /** XYZ template ({z}/{x}/{y}) or a TileJSON endpoint. */
  final String tilesUrl;
  /** Font glyph endpoint: {fontstack}/{range}.pbf. Required for map labels. */
  final String glyphsUrl;
  /** Attribution shown on the map. Required by the ODbL licence. */
  final String attribution;
  /**
   * Tile schema the style is written against. The style in `style.dart` selects
   * OMT layer names (water, transportation, building, place); pointing this at
   * a server using a different schema (Shortbread, Protomaps) renders a blank
   * map even though tiles load fine.
   */
  final String schema;

  const TileSourceConfig({
    required this.tilesUrl,
    required this.glyphsUrl,
    required this.attribution,
    required this.schema,
  });
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

final tileSource = TileSourceConfig(
  tilesUrl: const String.fromEnvironment('EXPO_PUBLIC_MAP_TILES_URL').isNotEmpty
    ? const String.fromEnvironment('EXPO_PUBLIC_MAP_TILES_URL')
    : TILES_URL,
  glyphsUrl: const String.fromEnvironment('EXPO_PUBLIC_MAP_GLYPHS_URL').isNotEmpty
    ? const String.fromEnvironment('EXPO_PUBLIC_MAP_GLYPHS_URL')
    : GLYPHS_URL,
  attribution: const String.fromEnvironment('EXPO_PUBLIC_MAP_ATTRIBUTION').isNotEmpty
    ? const String.fromEnvironment('EXPO_PUBLIC_MAP_ATTRIBUTION')
    : ATTRIBUTION,
  schema: 'openmaptiles',
);

/** True when the app is still pointed at a localhost dev tile server. */
bool isUsingDevTiles() {
  return tileSource.tilesUrl.contains('localhost') || tileSource.tilesUrl.contains('127.0.0.1');
}

/**
 * Template for "share my location" links, which are opened by the recipient in
 * a browser rather than rendered by us. Kept here so no screen hardcodes a map
 * provider; point it at an ELLY web map when one exists.
 */
final SHARE_URL_TEMPLATE =
  const String.fromEnvironment('EXPO_PUBLIC_MAP_SHARE_URL').isNotEmpty
    ? const String.fromEnvironment('EXPO_PUBLIC_MAP_SHARE_URL')
    : 'https://www.openstreetmap.org/?mlat={lat}&mlon={lon}';

/** Build a shareable link to a coordinate. */
String shareLocationUrl(double latitude, double longitude) {
  return SHARE_URL_TEMPLATE.replaceFirst('{lat}', latitude.toString()).replaceFirst('{lon}', longitude.toString());
}