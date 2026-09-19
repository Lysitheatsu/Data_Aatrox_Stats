/**
 * Flutter map — MapLibre rendering the same self-hosted OpenStreetMap vector
 * tiles and the same generated style as the original build.
 *
 * This replaces the separate React Native native map implementation with the
 * Flutter MapLibre implementation.
 *
 * Requires the MapLibre Flutter package.
 */
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:maplibre/maplibre.dart';
import '../api/client.dart';
import '../components/Avatar.dart';
import '../theme/index.dart';
import '../theme/ThemeProvider.dart';
import 'style.dart';
import 'TileSource.dart';
import 'types.dart';

const SHEET_CAMERA_DURATION = 180;
EdgeInsets cameraPadding(double bottomInset) => EdgeInsets.only(
  top: 80,
  bottom: bottomInset + 40,
  left: 50,
  right: 50,
);

class EllyMap extends HookWidget {
  final GeoLocation? focus;
  final bool showFocusMarker;
  final GeoLocation? origin;
  final double? heading;
  final List<LiveLocation>? liveLocations;
  final GeoLocation? liveFocus;
  final ValueChanged<LiveLocation>? onSelectLiveLocation;
  final List<List<double>>? routeGeometry;
  final List<double>? followStep;
  final LiveFollow? liveFollow;
  final int recenterSignal;
  final double bottomInset;
  final MapType mapType;

  const EllyMap({
    super.key,
    this.focus,
    this.showFocusMarker = true,
    this.origin,
    this.heading,
    this.liveLocations,
    this.liveFocus,
    this.onSelectLiveLocation,
    this.routeGeometry,
    this.followStep,
    this.liveFollow,
    this.recenterSignal = 0,
    this.bottomInset = 0,
    this.mapType = 'default',
  });

  @override
  Widget build(BuildContext context) {
    final theme = useAppTheme(context);
    final colors = theme.colors;
    final isDark = theme.isDark;
    final cameraRef = useRef<MapController?>(null);

    // Rebuilding the style object on every render would reload the map, so it is
    // memoised against the palette. A theme flip intentionally does rebuild it.
    final mapStyle = useMemoized(() => jsonEncode(buildMapStyle(colors, isDark)), [colors, isDark]);

    final centre = focus ?? DEFAULT_CENTER;
    final cameraCenterRef = useRef<Geographic>(Geographic(lon: centre.longitude, lat: centre.latitude));
    final bottomInsetRef = useRef(bottomInset);
    final styles = _makeStyles(colors, isDark);

    useEffect(() {
      cameraRef.value?.setStyle(mapStyle);
      return null;
    }, [mapStyle]);

    // Preserve the geographic centre chosen by the user when the sheet opens or
    // closes. The new padding places it in the centre of the remaining map area.
    useEffect(() {
      final previousInset = bottomInsetRef.value;
      bottomInsetRef.value = bottomInset;
      if (previousInset == bottomInset) return null;
      cameraRef.value?.animateCamera(
        center: cameraCenterRef.value,
        padding: cameraPadding(bottomInset),
        nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
      );
      return null;
    }, [bottomInset]);

    // A new search result may intentionally choose a new centre. Sheet changes
    // do not run this effect, so a manual pan remains intact.
    useEffect(() {
      final next = focus != null
        ? Geographic(lon: focus!.longitude, lat: focus!.latitude)
        : Geographic(lon: DEFAULT_CENTER.longitude, lat: DEFAULT_CENTER.latitude);
      cameraCenterRef.value = next;
      cameraRef.value?.animateCamera(
        center: next,
        zoom: focus != null ? FOCUS_ZOOM : DEFAULT_ZOOM,
        padding: cameraPadding(bottomInsetRef.value),
        nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
      );
      return null;
    }, [focus]);

    // Kept in a ref so the recenter effect below only runs when the navigate
    // button is pressed, not every time a fresh GPS fix comes in.
    final originRef = useRef(origin);
    useEffect(() {
      originRef.value = origin;
      return null;
    }, [origin]);

    // the navigate button: fly back to where you are
    useEffect(() {
      final here = originRef.value;
      // 0 means nobody has pressed it yet
      if (here == null || recenterSignal == 0) return null;
      cameraRef.value?.animateCamera(
        center: Geographic(lon: here.longitude, lat: here.latitude),
        zoom: FOCUS_ZOOM,
        padding: cameraPadding(bottomInsetRef.value),
        nativeDuration: const Duration(milliseconds: 900),
        webMaxDuration: const Duration(milliseconds: 900),
      );
      cameraCenterRef.value = Geographic(lon: here.longitude, lat: here.latitude);
      return null;
    }, [recenterSignal]);

    useEffect(() {
      if (focus != null || liveFocus != null || liveLocations == null || liveLocations!.isEmpty) return null;
      final longitudes = liveLocations!.map((person) => person.location.longitude).toList();
      final latitudes = liveLocations!.map((person) => person.location.latitude).toList();
      cameraRef.value?.fitBounds(
        bounds: LngLatBounds(
          longitudeWest: longitudes.reduce((a, b) => a < b ? a : b),
          longitudeEast: longitudes.reduce((a, b) => a > b ? a : b),
          latitudeSouth: latitudes.reduce((a, b) => a < b ? a : b),
          latitudeNorth: latitudes.reduce((a, b) => a > b ? a : b),
        ),
        padding: EdgeInsets.fromLTRB(50, 80, 50, bottomInsetRef.value + 40),
        nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
      );
      return null;
    }, [liveLocations, focus, liveFocus]);

    useEffect(() {
      if (liveFocus == null) return null;
      cameraCenterRef.value = Geographic(lon: liveFocus!.longitude, lat: liveFocus!.latitude);

      cameraRef.value?.animateCamera(
        center: cameraCenterRef.value,
        zoom: LIVE_FOCUS_ZOOM,
        padding: cameraPadding(bottomInsetRef.value),
        nativeDuration: const Duration(milliseconds: 400),
        webMaxDuration: const Duration(milliseconds: 400),
      );
      return null;
    }, [liveFocus, bottomInset]);

    return Container(
      color: styles.root.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              options: MapOptions(
                initStyle: mapStyle,
                initCenter: cameraCenterRef.value,
                initZoom: focus != null ? FOCUS_ZOOM : DEFAULT_ZOOM,
              ),
              onMapCreated: (controller) {
                cameraRef.value = controller;
                controller.moveCamera(
                  center: cameraCenterRef.value,
                  zoom: focus != null ? FOCUS_ZOOM : DEFAULT_ZOOM,
                  padding: cameraPadding(bottomInset),
                );
              },
              onEvent: (event) {
                if (event is MapEventMoveCamera) {
                  cameraCenterRef.value = event.camera.center;
                }
              },
              children: [
                WidgetLayer(
                  allowInteraction: true,
                  markers: [
                    ...(liveLocations ?? []).map((person) => Marker(
                      point: Geographic(lon: person.location.longitude, lat: person.location.latitude),
                      size: const Size(40, 40),
                      child: Semantics(
                        button: true,
                        label: 'Show ${person.name} on map',
                        child: GestureDetector(
                          onTap: () => onSelectLiveLocation?.call(person),
                          child: Avatar(
                            name: person.name,
                            size: 40,
                            ring: colors.live,
                          ),
                        ),
                      ),
                    )),
                    if (focus != null && showFocusMarker)
                      Marker(
                        point: Geographic(lon: focus!.longitude, lat: focus!.latitude),
                        size: Size(styles.pin.width, styles.pin.height),
                        child: Container(
                          width: styles.pin.width,
                          height: styles.pin.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(styles.pin.borderRadius),
                            color: styles.pin.backgroundColor,
                            border: Border.all(
                              width: styles.pin.borderWidth,
                              color: styles.pin.borderColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: styles.attribution.bottom,
            right: styles.attribution.right,
            child: Container(
              padding: styles.attribution.padding,
              decoration: BoxDecoration(
                color: styles.attribution.backgroundColor,
                borderRadius: BorderRadius.circular(styles.attribution.borderRadius),
              ),
              child: Text(tileSource.attribution, style: styles.attribution.textStyle),
            ),
          ),
        ],
      ),
    );
  }
}

({
  ({Color backgroundColor}) root,
  ({
    double width,
    double height,
    double borderRadius,
    Color backgroundColor,
    double borderWidth,
    Color borderColor,
  }) pin,
  ({
    double bottom,
    double right,
    EdgeInsets padding,
    TextStyle textStyle,
    Color backgroundColor,
    double borderRadius,
  }) attribution,
}) _makeStyles(ThemeColors colors, bool isDark) {
  return (
    root: (backgroundColor: colors.mapBackdrop,),
    pin: (
      width: 18,
      height: 18,
      borderRadius: 9,
      backgroundColor: colors.primary,
      borderWidth: 3,
      borderColor: colors.onAccent,
    ),
    attribution: (
      bottom: spacing.xs,
      right: spacing.xs,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: 2,
      ),
      textStyle: TextStyle(
        fontSize: fontSize.xs,
        color: colors.textMuted,
      ),
      backgroundColor: withAlpha(isDark ? colors.background : colors.onAccent, 0.7),
      borderRadius: 4,
    ),
  );
}