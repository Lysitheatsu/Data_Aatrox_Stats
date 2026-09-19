/**
 * Native map (iOS / Android) — MapLibre Native rendering the same self-hosted
 * OpenStreetMap vector tiles and the same generated style as the web build.
 *
 * This replaces the "available on the web version" placeholder that native
 * used to show. Metro picks EllyMap.web.tsx on web and this file elsewhere.
 *
 * Requires a development build: MapLibre is native code and does not run in
 * Expo Go. See MAP_SETUP.md.
 */
import React, { useEffect, useMemo, useRef } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Camera, MapView, MarkerView, PointAnnotation, type CameraRef } from '@maplibre/maplibre-react-native';
import { Avatar } from '@/components/Avatar';
import { fontSize, spacing, withAlpha, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { buildMapStyle } from './style';
import { tileSource } from './tileSource';
import { DEFAULT_CENTER, DEFAULT_ZOOM, FOCUS_ZOOM, LIVE_FOCUS_ZOOM, type EllyMapProps } from './types';

const SHEET_CAMERA_DURATION = 180;
const cameraPadding = (bottomInset: number) => ({
  paddingTop: 80,
  paddingBottom: bottomInset + 40,
  paddingLeft: 50,
  paddingRight: 50,
});

export function EllyMap({ focus, showFocusMarker = true, origin, liveLocations, liveFocus, onSelectLiveLocation, recenterSignal = 0, bottomInset = 0, mapType = 'default' }: EllyMapProps): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const cameraRef = useRef<CameraRef | null>(null);

  // Rebuilding the style object on every render would reload the map, so it is
  // memoised against the palette. A theme flip intentionally does rebuild it.
  const mapStyle = useMemo(() => buildMapStyle(colors, isDark), [colors, isDark]);

  const centre = focus ?? DEFAULT_CENTER;
  const cameraCenterRef = useRef<[number, number]>([centre.longitude, centre.latitude]);
  const bottomInsetRef = useRef(bottomInset);
  const styles = makeStyles(colors, isDark);

  // Preserve the geographic centre chosen by the user when the sheet opens or
  // closes. The new padding places it in the centre of the remaining map area.
  useEffect(() => {
    const previousInset = bottomInsetRef.current;
    bottomInsetRef.current = bottomInset;
    if (previousInset === bottomInset) return;
    cameraRef.current?.setCamera({
      centerCoordinate: cameraCenterRef.current,
      padding: cameraPadding(bottomInset),
      animationDuration: SHEET_CAMERA_DURATION,
      animationMode: 'easeTo',
    });
  }, [bottomInset]);

  // A new search result may intentionally choose a new centre. Sheet changes
  // do not run this effect, so a manual pan remains intact.
  useEffect(() => {
    const next: [number, number] = focus
      ? [focus.longitude, focus.latitude]
      : [DEFAULT_CENTER.longitude, DEFAULT_CENTER.latitude];
    cameraCenterRef.current = next;
    cameraRef.current?.setCamera({
      centerCoordinate: next,
      zoomLevel: focus ? FOCUS_ZOOM : DEFAULT_ZOOM,
      padding: cameraPadding(bottomInsetRef.current),
      animationDuration: SHEET_CAMERA_DURATION,
    });
  }, [focus]);

  // Kept in a ref so the recenter effect below only runs when the navigate
  // button is pressed, not every time a fresh GPS fix comes in.
  const originRef = useRef(origin);
  useEffect(() => {
    originRef.current = origin;
  }, [origin]);

  // the navigate button: fly back to where you are
  useEffect(() => {
    const here = originRef.current;
    // 0 means nobody has pressed it yet
    if (!here || recenterSignal === 0) return;
    cameraRef.current?.setCamera({
      centerCoordinate: [here.longitude, here.latitude],
      zoomLevel: FOCUS_ZOOM,
      padding: cameraPadding(bottomInsetRef.current),
      animationDuration: 900,
    });
    cameraCenterRef.current = [here.longitude, here.latitude];
  }, [recenterSignal]);

  useEffect(() => {
    if (focus || liveFocus || !liveLocations?.length) return;
    const longitudes = liveLocations.map(({ location }) => location.longitude);
    const latitudes = liveLocations.map(({ location }) => location.latitude);
    cameraRef.current?.fitBounds(
      [Math.max(...longitudes), Math.max(...latitudes)],
      [Math.min(...longitudes), Math.min(...latitudes)],
      [80, 50, bottomInsetRef.current + 40, 50],
      SHEET_CAMERA_DURATION,
    );
  }, [liveLocations, focus, liveFocus]);

  useEffect(() => {
    if (!liveFocus) return;
    cameraCenterRef.current = [liveFocus.longitude, liveFocus.latitude];

    cameraRef.current?.setCamera({
      centerCoordinate: cameraCenterRef.current,
      zoomLevel: LIVE_FOCUS_ZOOM,
      padding: cameraPadding(bottomInsetRef.current),
      animationDuration: 400,
    });
  }, [liveFocus, bottomInset]);

  return (
    <View style={styles.root}>
      <MapView
        style={StyleSheet.absoluteFill}
        mapStyle={mapStyle}
        logoEnabled={false}
        // We draw our own attribution to match the app's type styles.
        attributionEnabled={false}
        compassEnabled={false}
        onRegionDidChange={(feature) => {
          const [longitude, latitude] = feature.geometry.coordinates;
          cameraCenterRef.current = [longitude, latitude];
        }}
      >
        <Camera
          ref={cameraRef}
          defaultSettings={{
            centerCoordinate: cameraCenterRef.current,
            zoomLevel: focus ? FOCUS_ZOOM : DEFAULT_ZOOM,
            padding: cameraPadding(bottomInset),
          }}
        />

        {(liveLocations ?? []).map((person) => (
          <MarkerView
            key={person.id}
            coordinate={[person.location.longitude, person.location.latitude]}
          >
            <Pressable
              collapsable={false}
              accessibilityRole="button"
              accessibilityLabel={`Show ${person.name} on map`}
              onPress={() => onSelectLiveLocation?.(person)}
            >
              <Avatar
                name={person.name}
                size={40}
                ring={colors.live}
              />
            </Pressable>
          </MarkerView>
        ))}
        {focus && showFocusMarker ? (
          <PointAnnotation
            id="elly-focus"
            coordinate={[focus.longitude, focus.latitude]}
          >
            <View style={styles.pin} />
          </PointAnnotation>
        ) : null}
      </MapView>
      <Text style={styles.attribution}>{tileSource.attribution}</Text>
    </View>
  );
}

const makeStyles = (colors: ThemeColors, isDark: boolean) =>
  StyleSheet.create({
    root: { ...StyleSheet.absoluteFillObject, backgroundColor: colors.mapBackdrop },
    pin: {
      width: 18,
      height: 18,
      borderRadius: 9,
      backgroundColor: colors.primary,
      borderWidth: 3,
      borderColor: colors.onAccent,
    },
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