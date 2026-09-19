/**
 * Web map — maplibre-gl rendering self-hosted OpenStreetMap vector tiles.
 *
 * Replaces the old openstreetmap.org <iframe>. The iframe reloaded an entire
 * third-party page on every search; here a search is a camera animation over
 * tiles that are already loaded.
 *
 * The native implementation lives in EllyMap.tsx and shares this file's style
 * and props, so both platforms render from one source of truth.
 */
import React, { useEffect, useRef } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import maplibregl from 'maplibre-gl';
// Required for touch gestures: this stylesheet sets touch-action on the canvas
// container, without which mobile browsers pan/zoom the page instead of the map.
import 'maplibre-gl/dist/maplibre-gl.css';
import { fontSize, spacing, withAlpha } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { buildMapStyle } from './style';
import { tileSource } from './tileSource';
import { DEFAULT_CENTER, DEFAULT_ZOOM, FOCUS_ZOOM, LIVE_FOCUS_ZOOM, type EllyMapProps } from './types';

// names for the route line we add to the map
const ROUTE_SOURCE = 'elly-route';
const ROUTE_LAYER = 'elly-route-line';
const SHEET_CAMERA_DURATION = 180;
/** How long the dot takes to slide to a new gps reading. Roughly the gap
 *  between readings, so it's still moving when the next one lands. */
const MARKER_GLIDE_MS = 1000;
const SATELLITE_TILES =
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

const cameraPadding = (bottomInset: number) => ({
  top: 80,
  bottom: bottomInset + 40,
  left: 50,
  right: 50,
});

export function EllyMap({
  focus,
  showFocusMarker = true,
  origin,
  heading,
  liveLocations,
  liveFocus,
  onSelectLiveLocation,
  routeGeometry,
  followStep,
  liveFollow,
  recenterSignal = 0,
  bottomInset = 0,
  mapType = 'default',
}: EllyMapProps): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markerRef = useRef<maplibregl.Marker | null>(null);
  const originMarkerRef = useRef<maplibregl.Marker | null>(null);
  // used to slide the dot between gps readings instead of jumping
  const glideRef = useRef<number | null>(null);
  const glideFromRef = useRef<[number, number] | null>(null);
  const spinFromRef = useRef<number | null>(null);
  const bottomInsetRef = useRef(bottomInset);
  // kept here so we can redraw the line if the theme changes
  const routeRef = useRef<[number, number][]>([]);
  function getMapStyle(): maplibregl.StyleSpecification {
    if (mapType === 'satellite') {
      return {
        version: 8,
        sources: {
          satellite: {
            type: 'raster',
            tiles: [SATELLITE_TILES],
            tileSize: 256,
            attribution: 'Tiles © Esri',
          },
        },
        layers: [
          {
            id: 'satellite',
            type: 'raster',
            source: 'satellite',
          },
        ],
      };
    }

    return buildMapStyle(colors, isDark) as maplibregl.StyleSpecification;
  }

  // Create the map once. Re-creating it on every render would throw away the
  // tile cache and the current camera position.
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return undefined;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: getMapStyle(),
      center: [DEFAULT_CENTER.longitude, DEFAULT_CENTER.latitude],
      zoom: DEFAULT_ZOOM,
      // We render attribution ourselves below so it can be themed; the OSM
      // credit is required by the ODbL licence either way.
      attributionControl: false,
    });
    map.setPadding(cameraPadding(bottomInsetRef.current));
    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
      markerRef.current = null;
      originMarkerRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- init only
  }, []);

  // Draws the route line. Changing the theme wipes it off, so this gets
  // called again afterwards.
  const drawRoute = React.useCallback(
    (map: maplibregl.Map) => {
      const coords = routeRef.current;
      const existing = map.getSource(ROUTE_SOURCE) as maplibregl.GeoJSONSource | undefined;
      const data = {
        type: 'Feature' as const,
        properties: {},
        geometry: { type: 'LineString' as const, coordinates: coords },
      };

      if (coords.length === 0) {
        if (map.getLayer(ROUTE_LAYER)) map.removeLayer(ROUTE_LAYER);
        if (existing) map.removeSource(ROUTE_SOURCE);
        return;
      }

      if (existing) {
        existing.setData(data);
        return;
      }

      map.addSource(ROUTE_SOURCE, { type: 'geojson', data });
      map.addLayer({
        id: ROUTE_LAYER,
        type: 'line',
        source: ROUTE_SOURCE,
        layout: { 'line-cap': 'round', 'line-join': 'round' },
        paint: {
          'line-color': colors.primary,
          'line-width': 5,
          'line-opacity': 0.85,
        },
      });
    },
    [colors.primary],
  );

  // Switch between the normal ELLY map and satellite imagery.
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    map.setStyle(getMapStyle());

    map.once('styledata', () => {
      drawRoute(map);
    });
  }, [mapType, colors, isDark, drawRoute]);

  // the dot showing where you are, with an arrow for which way you're facing
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (!origin) {
      originMarkerRef.current?.remove();
      originMarkerRef.current = null;
      return;
    }

    // build it once, then just move it. remaking it every time made the dot
    // flicker as the position came in.
    if (!originMarkerRef.current) {
      // both sit on top of each other, we just show one at a time: the circle
      // when we don't know which way you're facing, the arrow once we do
      const wrap = document.createElement('div');
      wrap.style.cssText =
        'position:relative;width:26px;height:26px;display:flex;align-items:center;justify-content:center';

      // drawn as an svg rather than the usual css border triangle. that trick
      // needs a 0x0 box and safari on iphone doesn't always paint it, so you
      // end up with no arrow at all.
      const arrow = document.createElement('div');
      arrow.dataset.role = 'heading';
      arrow.style.cssText = 'position:absolute;width:26px;height:26px;display:none';
      arrow.innerHTML =
        `<svg width="26" height="26" viewBox="0 0 22 22" xmlns="http://www.w3.org/2000/svg">` +
        `<path d="M11 2 L19 19 L11 14.5 L3 19 Z" fill="${colors.primary}" ` +
        `stroke="${colors.onAccent}" stroke-width="2" stroke-linejoin="round"/></svg>`;

      // a circle, so it looks different to the destination pin
      const dot = document.createElement('div');
      dot.dataset.role = 'dot';
      dot.style.cssText = [
        'position:absolute',
        'width:16px',
        'height:16px',
        'border-radius:50%',
        `background:${colors.primary}`,
        `border:3px solid ${colors.onAccent}`,
        'box-shadow:0 0 0 1px rgba(0,0,0,0.15)',
      ].join(';');

      wrap.append(dot, arrow);
      // rotation follows the map so the arrow keeps pointing the right way
      // when the map spins. pitch stays on the viewport, otherwise the tilt
      // during navigation squashes the arrow down to almost nothing.
      // needs a position before addTo, it reads the coords straight away
      originMarkerRef.current = new maplibregl.Marker({
        element: wrap,
        rotationAlignment: 'map',
        pitchAlignment: 'viewport',
      })
        .setLngLat([origin.longitude, origin.latitude])
        .addTo(map);
    }

    const marker = originMarkerRef.current;
    const facing = heading ?? null;

    // once we know which way you're going, swap the circle for the arrow
    const element = marker.getElement();
    const arrow = element.querySelector<HTMLElement>('[data-role="heading"]');
    const dot = element.querySelector<HTMLElement>('[data-role="dot"]');
    if (arrow) arrow.style.display = facing === null ? 'none' : 'block';
    if (dot) dot.style.display = facing === null ? 'block' : 'none';

    // slide to the new spot instead of jumping straight there. gps only comes
    // in about once a second, so without this the dot hops along.
    const target: [number, number] = [origin.longitude, origin.latitude];
    const from = glideFromRef.current ?? target;
    const spinFrom = spinFromRef.current ?? facing ?? 0;
    const spinTo = facing ?? spinFrom;
    // go the short way round, so 350 -> 10 doesn't spin nearly all the way back
    let spinBy = ((spinTo - spinFrom + 540) % 360) - 180;

    if (glideRef.current) cancelAnimationFrame(glideRef.current);
    const startedAt = performance.now();
    const glide = (now: number) => {
      const t = Math.min(1, (now - startedAt) / MARKER_GLIDE_MS);
      const lng = from[0] + (target[0] - from[0]) * t;
      const lat = from[1] + (target[1] - from[1]) * t;
      glideFromRef.current = [lng, lat];
      spinFromRef.current = spinFrom + spinBy * t;
      marker.setLngLat([lng, lat]);
      marker.setRotation(spinFromRef.current);
      if (t < 1) glideRef.current = requestAnimationFrame(glide);
    };
    glideRef.current = requestAnimationFrame(glide);
  }, [origin, heading, colors.primary, colors.onAccent]);

  // stop the glide if the map goes away mid-animation
  useEffect(
    () => () => {
      if (glideRef.current) cancelAnimationFrame(glideRef.current);
    },
    [],
  );

  // zoom in on the turn you're currently on while navigating
  useEffect(() => {
    const map = mapRef.current;
    // liveFollow takes over the camera when it's on, don't fight it
    if (!map || !followStep || liveFollow) return;
    // flat and north-up, otherwise the tilt from live nav sticks around
    map.flyTo({ center: followStep, zoom: 17, pitch: 0, bearing: 0, duration: 700 });
  }, [followStep, liveFollow]);

  // live navigation: stay on the user and turn the map so the way they're
  // going points up, like a car sat nav
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !liveFollow) return;
    map.easeTo({
      center: [liveFollow.location.longitude, liveFollow.location.latitude],
      zoom: 17,
      bearing: liveFollow.bearing ?? map.getBearing(),
      pitch: 50,
      duration: MARKER_GLIDE_MS,
      // linear, so it keeps pace with the dot instead of speeding up and
      // slowing down between every reading
      easing: (t) => t,
    });
  }, [liveFollow]);

  // put the map back to flat and north-up when navigation stops. skipped while
  // followStep is set, the effect above handles that one and this would cancel
  // its fly-to halfway.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || liveFollow || followStep) return;
    if (map.getPitch() !== 0 || map.getBearing() !== 0) {
      map.easeTo({ pitch: 0, bearing: 0, duration: 600 });
    }
  }, [liveFollow, followStep]);

  // Kept in a ref so the recenter effect below only runs when the button is
  // pressed, not every time a fresh GPS fix comes in.
  const originRef = useRef(origin);
  useEffect(() => {
    originRef.current = origin;
  }, [origin]);

  // the navigate button: fly back to where you are
  useEffect(() => {
    const map = mapRef.current;
    const here = originRef.current;
    // 0 means nobody has pressed it yet
    if (!map || !here || recenterSignal === 0) return;
    map.flyTo({
      center: [here.longitude, here.latitude],
      zoom: FOCUS_ZOOM,
      duration: 900,
    });
  }, [recenterSignal]);

  // Keep the user's chosen map centre when the sheet changes height. Updating
  // only the padding moves that point into the centre of the visible map area.
  useEffect(() => {
    const map = mapRef.current;
    const previousInset = bottomInsetRef.current;
    bottomInsetRef.current = bottomInset;
    if (!map || previousInset === bottomInset) return;

    map.easeTo({
      center: map.getCenter(),
      padding: cameraPadding(bottomInset),
      duration: SHEET_CAMERA_DURATION,
    });
  }, [bottomInset]);

  // draw the route and zoom out so you can see all of it
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    routeRef.current = routeGeometry ?? [];

    const paint = () => {
      drawRoute(map);
      // don't pull the camera back out if we're following a turn
      if (routeRef.current.length > 1 && !followStep) {
        const bounds = routeRef.current.reduce(
          (acc, coord) => acc.extend(coord),
          new maplibregl.LngLatBounds(routeRef.current[0], routeRef.current[0]),
        );
        // Keep the route inside the part of the map above the bottom sheet.
        map.fitBounds(bounds, {
          padding: cameraPadding(bottomInsetRef.current),
          duration: SHEET_CAMERA_DURATION,
          maxZoom: 16,
        });
      }
    };

    if (map.isStyleLoaded()) paint();
    else map.once('load', paint);
  }, [routeGeometry, drawRoute, followStep]);

  // Search result: animate to the place and pin it.
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    if (!focus) {
      markerRef.current?.remove();
      markerRef.current = null;
      map.flyTo({
        center: [DEFAULT_CENTER.longitude, DEFAULT_CENTER.latitude],
        zoom: DEFAULT_ZOOM,
        duration: SHEET_CAMERA_DURATION,
      });
      return;
    }

    const lngLat: [number, number] = [focus.longitude, focus.latitude];
    // if there's a route we already zoomed to fit it, don't fight that
    if (!routeGeometry || routeGeometry.length < 2) {
      map.flyTo({
        center: lngLat,
        zoom: FOCUS_ZOOM,
        padding: cameraPadding(bottomInsetRef.current),
        duration: SHEET_CAMERA_DURATION,
      });
    }

    // Marker colour tracks the theme, so it is rebuilt when the palette flips.
    markerRef.current?.remove();
    markerRef.current = null;
    if (!showFocusMarker) return;
    markerRef.current = new maplibregl.Marker({ color: colors.primary })
      .setLngLat(lngLat)
      .addTo(map);
  }, [focus, colors.primary, routeGeometry, showFocusMarker]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    const markers = (liveLocations ?? []).map((person) => {
      const label = document.createElement('button');
      label.type = 'button';
      label.onclick = () => onSelectLiveLocation?.(person);
      label.setAttribute('aria-label', `${person.name}, ${person.location.label}, live location`);
      label.style.cssText = `background:${colors.background};color:${colors.text};border:3px solid ${colors.live};border-radius:50%;width:40px;height:40px;padding:0;overflow:hidden;font:600 13px sans-serif;box-shadow:0 2px 8px #0003;cursor:pointer`;
      const icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      icon.setAttribute('viewBox', '0 0 24 24');
      icon.setAttribute('width', '24');
      icon.setAttribute('height', '24');
      icon.setAttribute('aria-hidden', 'true');
      icon.style.cssText = 'display:block;margin:auto;fill:currentColor';
      const head = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      head.setAttribute('cx', '12');
      head.setAttribute('cy', '7');
      head.setAttribute('r', '4');
      const shoulders = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      shoulders.setAttribute('d', 'M4 21v-2a8 7 0 0 1 16 0v2z');
      icon.append(head, shoulders);
      label.appendChild(icon);
      return new maplibregl.Marker({ element: label })
        .setLngLat([person.location.longitude, person.location.latitude])
        .addTo(map);
    });
    return () => { markers.forEach((marker) => marker.remove()); };
  }, [liveLocations, colors, onSelectLiveLocation]);

  // Frame shared locations in the visible area above the journey sheet.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || focus || liveFocus || !liveLocations?.length) return;
    const bounds = new maplibregl.LngLatBounds();
    liveLocations.forEach(({ location }) => bounds.extend([location.longitude, location.latitude]));
    map.fitBounds(bounds, { padding: cameraPadding(bottomInsetRef.current), maxZoom: 14, duration: SHEET_CAMERA_DURATION });
  }, [liveLocations, focus, liveFocus, colors.primary]);

  useEffect(() => {
    if (!liveFocus) return;
    mapRef.current?.flyTo({ center: [liveFocus.longitude, liveFocus.latitude], zoom: LIVE_FOCUS_ZOOM, padding: cameraPadding(bottomInsetRef.current), duration: 400 });
  }, [liveFocus, bottomInset]);

  const styles = makeStyles(colors, isDark);

  return (
    <View style={styles.root}>
      {React.createElement('div', {
        ref: containerRef,
        'data-testid': 'elly-map-canvas',
        style: { position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' },
      })}
      <Text style={styles.attribution}>
        {mapType === 'satellite' ? 'Tiles © Esri' : tileSource.attribution}
      </Text>
    </View>
  );
}

const makeStyles = (colors: ReturnType<typeof useAppTheme>['colors'], isDark: boolean) =>
  StyleSheet.create({
    root: { ...StyleSheet.absoluteFillObject, backgroundColor: colors.mapBackdrop },
    attribution: {
      position: 'absolute',
      bottom: spacing.xs,
      right: spacing.xs,
      paddingHorizontal: spacing.xs,
      paddingVertical: 2,
      fontSize: fontSize.xs,
      color: colors.textMuted,
      backgroundColor: withAlpha(isDark ? colors.background : colors.onAccent, 0.7),
      borderRadius: 4,
      overflow: 'hidden',
    },
  });