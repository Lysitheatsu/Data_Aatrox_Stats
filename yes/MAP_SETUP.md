# Map Setup — ELLY Maps

The map renders **OpenStreetMap** data using **MapLibre GL**, styled entirely
from the app's own design tokens. This document covers how to run it locally
and how to point it at the production tile server.

## The stack, and who owns what

| Layer | What it is | Owned by |
| --- | --- | --- |
| OpenStreetMap | The underlying map data | OSM community |
| OpenMapTiles (OMT) | Schema the data is packaged into | Tile server |
| `src/map/style.ts` | Colours for every road, park and label | **This repo** |
| MapLibre GL | Renderer (web + native) | Library |

Theming lives entirely in this repo. The tile server supplies untyped
geometry; the style decides what it looks like.

## ⚠️ The one hard requirement: schema

The style selects **OpenMapTiles** layer names (`water`, `transportation`,
`building`, `place`, `landcover`, `boundary`). These names come from the tile
*schema*, not the host.

Pointing the app at a server that uses a different schema (Shortbread,
Protomaps basemap) produces **a blank map with no errors** — tiles load fine,
but no layer matches. If that happens, the schema is the first thing to check.

The declared expectation is recorded in `src/map/tileSource.ts` as
`schema: 'openmaptiles'`.

## Local development

Tiles are generated locally, so development needs no access to the production
tile server and no third-party map account.

### Prerequisite: Java 21+

Tile generation uses Planetiler, which requires **Java 21 or later**. Check
with `java -version`. On Windows:

```powershell
winget install EclipseAdoptium.Temurin.21.JDK
```

Open a new terminal afterwards so `PATH` picks it up. `npm run tiles:build`
checks this and fails with a clear message rather than a Java stack trace.

### Running it

`tiles:serve` and `web` are both long-running servers, so this needs **three
terminals**. All commands run from the `frontend/` directory.

> Windows PowerShell 5.1 does not support `&&`. Use `;` to chain, or run the
> commands one at a time.

```powershell
# Terminal 1 — one-off: generate local OSM tiles.
# First run downloads ~100MB of tooling plus the OSM extract; takes a few minutes.
cd frontend
npm install
npm run tiles:build

# Terminal 2 — serve the tiles at http://localhost:8080 (leave running)
cd frontend
npm run tiles:serve

# Terminal 3 — start the app (leave running)
cd frontend
npm run web
```

Once tiles are built, day-to-day work only needs terminals 2 and 3.

### Checking it worked

With both servers up:

```powershell
npm run map:check
```

Reports whether the MapLibre canvas initialised and lists any failed tile
requests. `ERR_CONNECTION_REFUSED` on `localhost:8080` means the tile server
(terminal 2) is not running.

`tiles:build` runs [Planetiler](https://github.com/onthegomap/planetiler),
whose default profile emits the OpenMapTiles schema — the same schema
production uses, so the style is validated against real layer names before
handover.

The first build downloads about 2.1GB of supporting data (water polygons,
Natural Earth, lake centerlines) plus an ~88MB Melbourne extract, and produces
a ~44MB archive in roughly 5 minutes. Later rebuilds reuse the downloads.

Output lands in `frontend/tiles/`, which is gitignored — the archive and the
downloaded sources are far too large to commit.

### Changing the region

City-sized extracts come from [BBBike](https://download.bbbike.org/osm/bbbike/);
set `ELLY_OSM_URL` to a different city's `.osm.pbf`.

Planetiler's `--area` flag only accepts **Geofabrik** region names, which are
country or state sized — there is no `melbourne` region, and passing one fails
with `No matches for 'melbourne'`. To use a Geofabrik region instead, set
`ELLY_TILE_AREA` (e.g. `australia`) and leave `ELLY_OSM_URL` empty.

`tiles:serve` exposes standard `{z}/{x}/{y}` URLs — the same URL shape as the
production tile server, so moving between them is a config change only.

## Configuration

All map configuration is environment-driven, following the same pattern as
`EXPO_PUBLIC_API_URL` in `src/api/client.ts`. **No map URL is hardcoded in any
component.**

| Variable | Default (dev) | Notes |
| --- | --- | --- |
| `EXPO_PUBLIC_MAP_TILES_URL` | `http://localhost:8080/elly-melbourne/{z}/{x}/{y}.mvt` | XYZ template or TileJSON endpoint |
| `EXPO_PUBLIC_MAP_GLYPHS_URL` | `http://localhost:8080/fonts/{fontstack}/{range}.pbf` | Label glyphs, served locally |
| `EXPO_PUBLIC_MAP_ATTRIBUTION` | `© OpenMapTiles © OpenStreetMap contributors` | Both credits are required |
| `EXPO_PUBLIC_MAP_SHARE_URL` | `https://www.openstreetmap.org/?mlat={lat}&mlon={lon}` | "Share my location" links |

### Deploying against the self-hosted tile server

```bash
EXPO_PUBLIC_MAP_TILES_URL="https://tiles.example.com/data/v3/{z}/{x}/{y}.pbf"
EXPO_PUBLIC_MAP_GLYPHS_URL="https://tiles.example.com/fonts/{fontstack}/{range}.pbf"
```

No code changes are required.

Two things to confirm with whoever runs the tile server:

1. **Schema is OpenMapTiles** (see above).
2. **The glyph endpoint serves the `Noto Sans Regular` font stack.** Labels
   need font glyphs, which tiles do not include. If the server offers a
   different font, change `FONT` in `src/map/style.ts`. The prebuilt glyph
   packs are at [openmaptiles/fonts](https://github.com/openmaptiles/fonts);
   `npm run tiles:build` downloads the same pack for local use, so no
   third-party font host is involved at any point.

## Native (iOS / Android)

MapLibre is native code, so **the app requires a development build and will not
run in Expo Go**:

```powershell
npm run android   # expo run:android — needs the Android SDK
npm run ios       # expo run:ios — needs macOS + Xcode
```

These regenerate the native project automatically, so `android/` and `ios/`
are gitignored rather than committed. Run `npx expo prebuild` directly if you
want to inspect the generated project.

The Expo config plugin is registered in `app.json`, along with the
`android.package` / `ios.bundleIdentifier` that any native build requires.
**These are currently `com.ellymaps.app` — confirm the real identifiers with
the company before any release build.**

Note that `localhost` in `EXPO_PUBLIC_MAP_TILES_URL` refers to the device, not
your machine — on a physical device or emulator, point it at your machine's
LAN IP, or the map will be blank.

### Verification status

Prebuild and autolinking are verified: the config plugin applies and
`@maplibre/maplibre-react-native` resolves to `org.maplibre.reactnative`.
**The map itself has not been run on a device or emulator** — that needs an
Android SDK or macOS, neither of which was available when this was written.
Web is fully verified.

## How theming works

`buildMapStyle(colors, isDark)` in `src/map/style.ts` generates a complete
MapLibre style document from the palettes in `src/theme/index.ts`. Map colours
are derived in `mapPalette()` from the existing semantic tokens
(`mapBackdrop`, `mapPark`, `primary`, `text`, ...) rather than hardcoded, so
when the approved dark palette lands the map updates along with the rest of
the app.

Switching theme swaps the whole style document. Tiles stay cached, so the map
recolours in place without refetching.

## Files

| Path | Purpose |
| --- | --- |
| `src/map/tileSource.ts` | Env-driven tile server config |
| `src/map/style.ts` | Style generated from design tokens — **all theming** |
| `src/map/EllyMap.web.tsx` | Web renderer (maplibre-gl) |
| `src/map/EllyMap.tsx` | Native renderer (MapLibre Native) |
| `src/map/types.ts` | Shared props and default camera |
| `scripts/tiles.mjs` | Local tile build + dev tile server |
