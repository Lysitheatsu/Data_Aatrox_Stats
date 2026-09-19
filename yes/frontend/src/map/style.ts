/**
 * Builds a MapLibre style from the ELLY design tokens.
 *
 * This is where ALL map theming lives. The tile server sends untyped geometry
 * in the OpenMapTiles schema; this file decides what colour every road, park
 * and label is, so the map matches the rest of the app in both light and dark
 * mode instead of being a filtered screenshot.
 *
 * COLOR EDITING GUIDE
 * -------------------
 * Do not hardcode colours below. Everything is derived in `mapPalette()` from
 * the semantic tokens in `src/theme/index.ts`, so when the approved dark
 * palette lands the map updates with the rest of the app.
 *
 * Layer names (water, transportation, building, place, ...) come from the
 * OpenMapTiles schema. They are NOT arbitrary — see tileSource.ts.
 */
import { withAlpha, type ThemeColors } from '@/theme';
import { tileSource } from './tileSource';

/** Font stack must exist on the glyph server (tileSource.glyphsUrl). */
const FONT = ['Noto Sans Regular'];

/** Map-specific colours, all derived from the app's semantic tokens. */
function mapPalette(colors: ThemeColors, isDark: boolean) {
  return {
    land: colors.mapBackdrop,
    park: colors.mapPark,
    // Water leans on the brand accent so the map reads as "ELLY" at a glance.
    water: isDark ? withAlpha(colors.primaryDark, 0.55) : withAlpha(colors.primary, 0.22),
    building: isDark ? colors.surfaceAlt : colors.border,
    // Roads: major roads sit brighter than the land, minor roads sit closer to
    // it, so the hierarchy survives in both schemes.
    motorway: isDark ? colors.borderStrong : colors.onAccent,
    major: isDark ? colors.surfaceAlt : colors.onAccent,
    minor: isDark ? colors.surface : withAlpha(colors.onAccent, 0.85),
    roadCasing: isDark ? colors.background : colors.borderStrong,
    rail: colors.textFaint,
    boundary: colors.borderStrong,
    label: colors.text,
    labelMuted: colors.textMuted,
    // Halo lifts labels off busy geometry; matches the surface behind them.
    labelHalo: isDark ? colors.background : colors.onAccent,
  };
}

/** Road widths by zoom, shared by casing and fill so they stay concentric. */
const roadWidth = (scale: number): unknown => [
  'interpolate',
  ['exponential', 1.5],
  ['zoom'],
  6, 0.5 * scale,
  12, 2 * scale,
  16, 6 * scale,
  20, 24 * scale,
];

/**
 * Produce a complete MapLibre style document for the given palette.
 * Safe to call on every theme change — swapping the whole style is how the
 * map switches between light and dark.
 */
export function buildMapStyle(colors: ThemeColors, isDark: boolean): Record<string, unknown> {
  const c = mapPalette(colors, isDark);
  const vectorSource = tileSource.tilesUrl.includes('{z}')
    ? { type: 'vector', tiles: [tileSource.tilesUrl], minzoom: 0, maxzoom: 14 }
    : { type: 'vector', url: tileSource.tilesUrl, minzoom: 0, maxzoom: 14 };

  return {
    version: 8,
    name: `ELLY Maps (${isDark ? 'dark' : 'light'})`,
    glyphs: tileSource.glyphsUrl,
    sources: {
      // Source id is referenced by every layer below via "source".
      ellyOsm: {
        ...vectorSource,
        attribution: tileSource.attribution,
      },
    },
    layers: [
      { id: 'background', type: 'background', paint: { 'background-color': c.land } },

      // ── Landcover ────────────────────────────────────────────────────────
      {
        id: 'landcover-green',
        type: 'fill',
        source: 'ellyOsm',
        'source-layer': 'landcover',
        filter: ['in', ['get', 'class'], ['literal', ['wood', 'grass', 'scrub']]],
        paint: { 'fill-color': c.park, 'fill-opacity': 0.7 },
      },
      {
        id: 'park',
        type: 'fill',
        source: 'ellyOsm',
        'source-layer': 'park',
        paint: { 'fill-color': c.park, 'fill-opacity': 0.55 },
      },

      // ── Water ────────────────────────────────────────────────────────────
      {
        id: 'water',
        type: 'fill',
        source: 'ellyOsm',
        'source-layer': 'water',
        paint: { 'fill-color': c.water },
      },
      {
        id: 'waterway',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'waterway',
        paint: {
          'line-color': c.water,
          'line-width': ['interpolate', ['linear'], ['zoom'], 8, 0.5, 16, 3],
        },
      },

      // ── Buildings ────────────────────────────────────────────────────────
      {
        id: 'building',
        type: 'fill',
        source: 'ellyOsm',
        'source-layer': 'building',
        minzoom: 13,
        paint: {
          'fill-color': c.building,
          // Fade in rather than popping at z13.
          'fill-opacity': ['interpolate', ['linear'], ['zoom'], 13, 0, 15, isDark ? 0.7 : 0.9],
        },
      },

      // ── Roads: casings first, then fills, so joins look continuous ───────
      {
        id: 'road-casing',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'transportation',
        filter: ['!', ['in', ['get', 'class'], ['literal', ['path', 'ferry', 'rail']]]],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': c.roadCasing, 'line-width': roadWidth(1.35), 'line-opacity': 0.6 },
      },
      {
        id: 'road-minor',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'transportation',
        filter: ['in', ['get', 'class'], ['literal', ['minor', 'service', 'track']]],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': c.minor, 'line-width': roadWidth(0.8) },
      },
      {
        id: 'road-major',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'transportation',
        filter: ['in', ['get', 'class'], ['literal', ['primary', 'secondary', 'tertiary', 'trunk']]],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': c.major, 'line-width': roadWidth(1) },
      },
      {
        id: 'road-motorway',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'transportation',
        filter: ['==', ['get', 'class'], 'motorway'],
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: { 'line-color': c.motorway, 'line-width': roadWidth(1.2) },
      },
      {
        id: 'rail',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'transportation',
        filter: ['==', ['get', 'class'], 'rail'],
        minzoom: 11,
        paint: {
          'line-color': c.rail,
          'line-width': 1,
          'line-dasharray': [3, 3],
          'line-opacity': 0.6,
        },
      },

      // ── Boundaries ───────────────────────────────────────────────────────
      {
        id: 'boundary',
        type: 'line',
        source: 'ellyOsm',
        'source-layer': 'boundary',
        filter: ['<=', ['get', 'admin_level'], 4],
        paint: { 'line-color': c.boundary, 'line-width': 1, 'line-dasharray': [2, 2] },
      },

      // ── Labels ───────────────────────────────────────────────────────────
      {
        id: 'road-label',
        type: 'symbol',
        source: 'ellyOsm',
        'source-layer': 'transportation_name',
        minzoom: 13,
        layout: {
          'text-field': ['coalesce', ['get', 'name:en'], ['get', 'name']],
          'text-font': FONT,
          'text-size': 11,
          'symbol-placement': 'line',
        },
        paint: { 'text-color': c.labelMuted, 'text-halo-color': c.labelHalo, 'text-halo-width': 1.2 },
      },
      {
        id: 'water-label',
        type: 'symbol',
        source: 'ellyOsm',
        'source-layer': 'water_name',
        layout: {
          'text-field': ['coalesce', ['get', 'name:en'], ['get', 'name']],
          'text-font': FONT,
          'text-size': 12,
        },
        paint: { 'text-color': c.labelMuted, 'text-halo-color': c.labelHalo, 'text-halo-width': 1 },
      },
      {
        id: 'place-label',
        type: 'symbol',
        source: 'ellyOsm',
        'source-layer': 'place',
        filter: [
          'in',
          ['get', 'class'],
          ['literal', ['city', 'town', 'village', 'suburb', 'neighbourhood']],
        ],
        layout: {
          'text-field': ['coalesce', ['get', 'name:en'], ['get', 'name']],
          'text-font': FONT,
          // Cities read larger than suburbs.
          'text-size': ['interpolate', ['linear'], ['zoom'], 8, 11, 14, 15],
        },
        paint: { 'text-color': c.label, 'text-halo-color': c.labelHalo, 'text-halo-width': 1.4 },
      },
    ],
  };
}
