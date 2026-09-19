import '../api/client.dart';

/** Normal streets, or the satellite photo layer. */
typedef MapType = String;

class LiveLocation {
  final String id;
  final String name;
  final GeoLocation location;
  final String lastUpdated;

  const LiveLocation({
    required this.id,
    required this.name,
    required this.location,
    required this.lastUpdated,
  });
}

/** Props shared by the web and native map implementations. */
class EllyMapProps {
  /** Place to centre on and pin. Null shows the default city view. */
  final GeoLocation? focus;
  /** Shared-person destinations use their icon instead of a destination pin. */
  final bool? showFocusMarker;
  final List<LiveLocation>? liveLocations;
  final void Function(LiveLocation person)? onSelectLiveLocation;
  /** Camera-only focus for a shared location. */
  final GeoLocation? liveFocus;
  /** Where the user is, shown as a dot. */
  final GeoLocation? origin;
  /** Which way the user is facing, 0-360. Adds an arrow to the dot. */
  final double? heading;
  /** The route line, as [lon, lat] pairs from /maps/routes. */
  final List<List<double>>? routeGeometry;
  /** While navigating, the turn to centre on. Null means show the whole route. */
  final List<double>? followStep;
  /**
   * Bump this to fly the camera back to `origin`. It's a counter rather than a
   * boolean so pressing the button twice in a row still moves the map.
   */
  final int? recenterSignal;
  /** Height covered by the open bottom sheet. Camera framing avoids it. */
  final double? bottomInset;
  /** While live navigating, keep the camera on the user and face this way. */
  final LiveFollow? liveFollow;

  final MapType? mapType;

  const EllyMapProps({
    required this.focus,
    this.showFocusMarker,
    this.liveLocations,
    this.onSelectLiveLocation,
    this.liveFocus,
    this.origin,
    this.heading,
    this.routeGeometry,
    this.followStep,
    this.recenterSignal,
    this.bottomInset,
    this.liveFollow,
    this.mapType,
  });
}

class LiveFollow {
  final GeoLocation location;
  final double? bearing;

  const LiveFollow({
    required this.location,
    required this.bearing,
  });
}

/** Where the map opens before the user searches for anything. */
final DEFAULT_CENTER = GeoLocation(
  label: 'Melbourne CBD',
  latitude: -37.8136,
  longitude: 144.9631,
);

const DEFAULT_ZOOM = 14.0;
/** Zoom used when flying to a searched place. */
const FOCUS_ZOOM = 15.0;

/** Street-level framing when selecting a shared location. */
const LIVE_FOCUS_ZOOM = 16.0;