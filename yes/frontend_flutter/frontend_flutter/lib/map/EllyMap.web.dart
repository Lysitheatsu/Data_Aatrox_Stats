/**
 * Web map — MapLibre rendering self-hosted OpenStreetMap vector tiles.
 *
 * Replaces the old openstreetmap.org <iframe>. The iframe reloaded an entire
 * third-party page on every search; here a search is a camera animation over
 * tiles that are already loaded.
 *
 * The native implementation lives in elly_map.dart and shares this file's style
 * and props, so both platforms render from one source of truth.
 */
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:maplibre/maplibre.dart';
import '../api/client.dart';
import '../theme/index.dart';
import '../theme/ThemeProvider.dart';
import 'style.dart';
import 'tileSource.dart';
import 'types.dart';

// names for the route line we add to the map
const ROUTE_SOURCE = 'elly-route';
const ROUTE_LAYER = 'elly-route-line';
const SHEET_CAMERA_DURATION = 180;
/** How long the dot takes to slide to a new gps reading. Roughly the gap
 *  between readings, so it's still moving when the next one lands. */
const MARKER_GLIDE_MS = 1000;
const SATELLITE_TILES =
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

EdgeInsets cameraPadding(double bottomInset) => EdgeInsets.fromLTRB(
  50,
  80,
  50,
  bottomInset + 40,
);

EdgeInsets fitCameraPadding(BuildContext context, double bottomInset) {
  final size = MediaQuery.sizeOf(context);
  final horizontal = math.min(50.0, size.width * 0.15);
  final top = math.min(80.0, size.height * 0.15);
  final bottom = math.min(bottomInset + 40, size.height * 0.25);
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom,
  );
}

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
  final String mapType;

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
    final mapRef = useRef<MapController?>(null);
    final styleRef = useRef<StyleController?>(null);
    final routeAddedRef = useRef(false);
    // used to slide the dot between gps readings instead of jumping
    final glideRef = useRef<Timer?>(null);
    final glideFromRef = useRef<Geographic?>(null);
    final spinFromRef = useRef<double?>(null);
    final bottomInsetRef = useRef(bottomInset);
    // kept here so we can redraw the line if the theme changes
    final routeRef = useRef<List<List<double>>>([]);
    final glidePoint = useState<Geographic?>(
      origin != null
        ? Geographic(lon: origin!.longitude, lat: origin!.latitude)
        : null,
    );
    final glideHeading = useState<double?>(heading);

    String getMapStyle() {
      if (mapType == 'satellite') {
        return jsonEncode({
          'version': 8,
          'sources': {
            'satellite': {
              'type': 'raster',
              'tiles': [SATELLITE_TILES],
              'tileSize': 256,
              'attribution': 'Tiles © Esri',
            },
          },
          'layers': [
            {
              'id': 'satellite',
              'type': 'raster',
              'source': 'satellite',
            },
          ],
        });
      }

      return jsonEncode(buildMapStyle(colors, isDark));
    }

    // Draws the route line. Changing the theme wipes it off, so this gets
    // called again afterwards.
    final drawRoute = useMemoized<Future<void> Function(StyleController)>(
      () {
        return (StyleController style) async {
          final coords = routeRef.value;
          final data = jsonEncode({
            'type': 'Feature',
            'properties': {},
            'geometry': {
              'type': 'LineString',
              'coordinates': coords,
            },
          });

          if (coords.isEmpty) {
            if (routeAddedRef.value) {
              await style.removeLayer(ROUTE_LAYER);
              await style.removeSource(ROUTE_SOURCE);
              routeAddedRef.value = false;
            }
            return;
          }

          if (routeAddedRef.value) {
            await style.updateGeoJsonSource(
              id: ROUTE_SOURCE,
              data: data,
            );
            return;
          }

          await style.addSource(
            GeoJsonSource(
              id: ROUTE_SOURCE,
              data: data,
            ),
          );
          await style.addLayer(
            LineStyleLayer(
              id: ROUTE_LAYER,
              sourceId: ROUTE_SOURCE,
              layout: {
                'line-cap': 'round',
                'line-join': 'round',
              },
              paint: {
                'line-color': mapColor(colors.primary),
                'line-width': 5,
                'line-opacity': 0.85,
              },
            ),
          );
          routeAddedRef.value = true;
        };
      },
      [colors.primary],
    );

    // Switch between the normal ELLY map and satellite imagery.
    useEffect(() {
      final map = mapRef.value;
      if (map == null) return null;

      styleRef.value = null;
      routeAddedRef.value = false;
      map.setStyle(getMapStyle());

      return null;
    }, [mapType, colors, isDark, drawRoute]);

    // the dot showing where you are, with an arrow for which way you're facing
    useEffect(() {
      if (origin == null) {
        glideRef.value?.cancel();
        glideRef.value = null;
        glideFromRef.value = null;
        spinFromRef.value = null;
        glidePoint.value = null;
        glideHeading.value = null;
        return null;
      }

      final facing = heading;

      // once we know which way you're going, swap the circle for the arrow

      // slide to the new spot instead of jumping straight there. gps only comes
      // in about once a second, so without this the dot hops along.
      final target = Geographic(
        lon: origin!.longitude,
        lat: origin!.latitude,
      );
      final from = glideFromRef.value ?? target;
      final spinFrom = spinFromRef.value ?? facing ?? 0;
      final spinTo = facing ?? spinFrom;
      // go the short way round, so 350 -> 10 doesn't spin nearly all the way back
      final spinBy = (((spinTo - spinFrom + 540) % 360) - 180).toDouble();

      glideRef.value?.cancel();
      final startedAt = DateTime.now();
      glideRef.value = Timer.periodic(
        const Duration(milliseconds: 16),
        (timer) {
          final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
          final t = (elapsed / MARKER_GLIDE_MS).clamp(0.0, 1.0).toDouble();
          final lng = from.lon + (target.lon - from.lon) * t;
          final lat = from.lat + (target.lat - from.lat) * t;
          glideFromRef.value = Geographic(lon: lng, lat: lat);
          spinFromRef.value = spinFrom + spinBy * t;
          glidePoint.value = Geographic(lon: lng, lat: lat);
          glideHeading.value = spinFromRef.value;
          if (t >= 1) {
            timer.cancel();
            glideRef.value = null;
          }
        },
      );

      return null;
    }, [origin, heading, colors.primary, colors.onAccent]);

    // stop the glide if the map goes away mid-animation
    useEffect(
      () => () {
        glideRef.value?.cancel();
      },
      const [],
    );

    // zoom in on the turn you're currently on while navigating
    useEffect(() {
      final map = mapRef.value;
      // liveFollow takes over the camera when it's on, don't fight it
      if (map == null || followStep == null || liveFollow != null) return null;
      // flat and north-up, otherwise the tilt from live nav sticks around
      map.animateCamera(
        center: Geographic(
          lon: followStep![0],
          lat: followStep![1],
        ),
        zoom: 17,
        pitch: 0,
        bearing: 0,
        nativeDuration: const Duration(milliseconds: 700),
        webMaxDuration: const Duration(milliseconds: 700),
      ).catchError((_) {});
      return null;
    }, [followStep, liveFollow]);

    // live navigation: stay on the user and turn the map so the way they're
    // going points up, like a car sat nav
    useEffect(() {
      final map = mapRef.value;
      if (map == null || liveFollow == null) return null;
      map.animateCamera(
        center: Geographic(
          lon: liveFollow!.location.longitude,
          lat: liveFollow!.location.latitude,
        ),
        zoom: 17,
        bearing: liveFollow!.bearing ?? map.camera?.bearing ?? 0,
        pitch: 50,
        nativeDuration: const Duration(milliseconds: MARKER_GLIDE_MS),
        webMaxDuration: const Duration(milliseconds: MARKER_GLIDE_MS),
      ).catchError((_) {});
      return null;
    }, [liveFollow]);

    // put the map back to flat and north-up when navigation stops. skipped while
    // followStep is set, the effect above handles that one and this would cancel
    // its fly-to halfway.
    useEffect(() {
      final map = mapRef.value;
      if (map == null || liveFollow != null || followStep != null) return null;
      final camera = map.camera;
      if (camera != null && (camera.pitch != 0 || camera.bearing != 0)) {
        map.animateCamera(
          pitch: 0,
          bearing: 0,
          nativeDuration: const Duration(milliseconds: 600),
          webMaxDuration: const Duration(milliseconds: 600),
        ).catchError((_) {});
      }
      return null;
    }, [liveFollow, followStep]);

    // Kept in a ref so the recenter effect below only runs when the button is
    // pressed, not every time a fresh GPS fix comes in.
    final originRef = useRef(origin);
    useEffect(() {
      originRef.value = origin;
      return null;
    }, [origin]);

    // the navigate button: fly back to where you are
    useEffect(() {
      final map = mapRef.value;
      final here = originRef.value;
      // 0 means nobody has pressed it yet
      if (map == null || here == null || recenterSignal == 0) return null;
      map.animateCamera(
        center: Geographic(
          lon: here.longitude,
          lat: here.latitude,
        ),
        zoom: FOCUS_ZOOM,
        nativeDuration: const Duration(milliseconds: 900),
        webMaxDuration: const Duration(milliseconds: 900),
      ).catchError((_) {});
      return null;
    }, [recenterSignal]);

    // Keep the user's chosen map centre when the sheet changes height. Updating
    // only the padding moves that point into the centre of the visible map area.
    useEffect(() {
      final map = mapRef.value;
      final previousInset = bottomInsetRef.value;
      bottomInsetRef.value = bottomInset;
      if (map == null || previousInset == bottomInset) return null;

      map.animateCamera(
        center: map.camera?.center,
        padding: cameraPadding(bottomInset),
        nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
      ).catchError((_) {});
      return null;
    }, [bottomInset]);

    // draw the route and zoom out so you can see all of it
    useEffect(() {
      final map = mapRef.value;
      if (map == null) return null;

      routeRef.value = routeGeometry ?? [];

      final style = styleRef.value;
      if (style != null) {
        drawRoute(style);
      }

      // don't pull the camera back out if we're following a turn
      if (routeRef.value.length > 1 && followStep == null) {
        final bounds = LngLatBounds.fromPoints(
          routeRef.value.map((coord) => Geographic(
            lon: coord[0],
            lat: coord[1],
          )).toList(),
        );
        // Keep the route inside the part of the map above the bottom sheet.
        map.moveCamera(
          padding: EdgeInsets.zero,
        );

        map.fitBounds(
          bounds: bounds,
          padding: fitCameraPadding(context, bottomInsetRef.value),
          nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
          webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
          webMaxZoom: 16,
        ).catchError((_) {});
      }

      return null;
    }, [routeGeometry, drawRoute, followStep]);

    // Search result: animate to the place and pin it.
    useEffect(() {
      final map = mapRef.value;
      if (map == null) return null;

      if (focus == null) {
        map.animateCamera(
          center: Geographic(
            lon: DEFAULT_CENTER.longitude,
            lat: DEFAULT_CENTER.latitude,
          ),
          zoom: DEFAULT_ZOOM,
          nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
          webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        ).catchError((_) {});
        return null;
      }

      final lngLat = Geographic(
        lon: focus!.longitude,
        lat: focus!.latitude,
      );
      // if there's a route we already zoomed to fit it, don't fight that
      if (routeGeometry == null || routeGeometry!.length < 2) {
        map.animateCamera(
          center: lngLat,
          zoom: FOCUS_ZOOM,
          padding: cameraPadding(bottomInsetRef.value),
          nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
          webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        ).catchError((_) {});
      }

      // Marker colour tracks the theme, so it is rebuilt when the palette flips.

      return null;
    }, [focus, colors.primary, routeGeometry, showFocusMarker]);

    // Frame shared locations in the visible area above the journey sheet.
    useEffect(() {
      final map = mapRef.value;
      if (map == null ||
          focus != null ||
          liveFocus != null ||
          liveLocations == null ||
          liveLocations!.isEmpty) {
        return null;
      }

      if (liveLocations!.length == 1) {
        final location = liveLocations!.first.location;

        map.animateCamera(
          center: Geographic(
            lon: location.longitude,
            lat: location.latitude,
          ),
          zoom: LIVE_FOCUS_ZOOM,
          padding: cameraPadding(bottomInsetRef.value),
          nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
          webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        ).catchError((_) {});

        return null;
      }

      final bounds = LngLatBounds.fromPoints(
        liveLocations!.map((person) => Geographic(
          lon: person.location.longitude,
          lat: person.location.latitude,
        )).toList(),
      );
      
      map.moveCamera(
          padding: EdgeInsets.zero,
        );

      map.fitBounds(
        bounds: bounds,
        padding: fitCameraPadding(context, bottomInsetRef.value),
        nativeDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        webMaxDuration: const Duration(milliseconds: SHEET_CAMERA_DURATION),
        webMaxZoom: 14,
      ).catchError((_) {});
      return null;
    }, [liveLocations, focus, liveFocus, colors.primary]);

    useEffect(() {
      final map = mapRef.value;
      if (map == null || liveFocus == null) return null;
      map.animateCamera(
        center: Geographic(
          lon: liveFocus!.longitude,
          lat: liveFocus!.latitude,
        ),
        zoom: LIVE_FOCUS_ZOOM,
        padding: cameraPadding(bottomInsetRef.value),
        nativeDuration: const Duration(milliseconds: 400),
        webMaxDuration: const Duration(milliseconds: 400),
      ).catchError((_) {});
      return null;
    }, [liveFocus, bottomInset]);

    final styles = makeStyles(colors, isDark);

    return Container(
      color: styles.root.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              options: MapOptions(
                initStyle: getMapStyle(),
                initCenter: Geographic(
                  lon: DEFAULT_CENTER.longitude,
                  lat: DEFAULT_CENTER.latitude,
                ),
                initZoom: DEFAULT_ZOOM,
              ),
              onMapCreated: (map) {
                mapRef.value = map;
                map.moveCamera(
                  padding: cameraPadding(bottomInsetRef.value),
                );
              },
              onStyleLoaded: (style) {
                styleRef.value = style;
                routeAddedRef.value = false;
                drawRoute(style);
              },
              children: [
                WidgetLayer(
                  allowInteraction: true,
                  markers: [
                    if (glidePoint.value != null)
                      Marker(
                        point: glidePoint.value!,
                        size: const Size(26, 26),
                        rotate: true,
                        flat: false,
                        child: heading != null
                          ? Transform.rotate(
                              angle: (glideHeading.value ?? heading ?? 0) * math.pi / 180,
                              child: CustomPaint(
                                size: const Size(26, 26),
                                painter: _HeadingPainter(
                                  fill: colors.primary,
                                  stroke: colors.onAccent,
                                ),
                              ),
                            )
                          : Center(
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primary,
                                  border: Border.all(
                                    width: 3,
                                    color: colors.onAccent,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.15),
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),
                    ...(liveLocations ?? []).map((person) => Marker(
                      point: Geographic(
                        lon: person.location.longitude,
                        lat: person.location.latitude,
                      ),
                      size: const Size(40, 40),
                      child: Semantics(
                        button: true,
                        label: '${person.name}, ${person.location.label}, live location',
                        child: GestureDetector(
                          onTap: () => onSelectLiveLocation?.call(person),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.background,
                              border: Border.all(
                                width: 3,
                                color: colors.live,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.2),
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person,
                              size: 24,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
                    )),
                    if (focus != null && showFocusMarker)
                      Marker(
                        point: Geographic(
                          lon: focus!.longitude,
                          lat: focus!.latitude,
                        ),
                        size: const Size(40, 40),
                        alignment: Alignment.bottomCenter,
                        child: Icon(
                          Icons.location_pin,
                          size: 40,
                          color: colors.primary,
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
              child: Text(
                mapType == 'satellite' ? 'Tiles © Esri' : tileSource.attribution,
                style: styles.attribution.textStyle,
              ),
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
    double bottom,
    double right,
    EdgeInsets padding,
    TextStyle textStyle,
    Color backgroundColor,
    double borderRadius,
  }) attribution,
}) makeStyles(ThemeColors colors, bool isDark) {
  return (
    root: (
      backgroundColor: colors.mapBackdrop,
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

class _HeadingPainter extends CustomPainter {
  final Color fill;
  final Color stroke;

  const _HeadingPainter({
    required this.fill,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 22;
    final scaleY = size.height / 22;
    final path = Path()
      ..moveTo(11 * scaleX, 2 * scaleY)
      ..lineTo(19 * scaleX, 19 * scaleY)
      ..lineTo(11 * scaleX, 14.5 * scaleY)
      ..lineTo(3 * scaleX, 19 * scaleY)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HeadingPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.stroke != stroke;
  }
}