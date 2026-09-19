import type { GeoLocation } from '@/api/client';

/** Normal streets, or the satellite photo layer. */
export type MapType = 'default' | 'satellite';

export interface LiveLocation {
  id: string;
  name: string;
  location: GeoLocation;
  lastUpdated: string;
}

/** Props shared by the web and native map implementations. */
export interface EllyMapProps {
  /** Place to centre on and pin. Null shows the default city view. */
  focus: GeoLocation | null;
  /** Shared-person destinations use their icon instead of a destination pin. */
  showFocusMarker?: boolean;
  liveLocations?: LiveLocation[];
  onSelectLiveLocation?: (person: LiveLocation) => void;
  /** Camera-only focus for a shared location. */
  liveFocus?: GeoLocation | null;
  /** Where the user is, shown as a dot. */
  origin?: GeoLocation | null;
  /** Which way the user is facing, 0-360. Adds an arrow to the dot. */
  heading?: number | null;
  /** The route line, as [lon, lat] pairs from /maps/routes. */
  routeGeometry?: [number, number][];
  /** While navigating, the turn to centre on. Null means show the whole route. */
  followStep?: [number, number] | null;
  /**
   * Bump this to fly the camera back to `origin`. It's a counter rather than a
   * boolean so pressing the button twice in a row still moves the map.
   */
  recenterSignal?: number;
  /** Height covered by the open bottom sheet. Camera framing avoids it. */
  bottomInset?: number;
  /** While live navigating, keep the camera on the user and face this way. */
  liveFollow?: { location: GeoLocation; bearing: number | null } | null;

  mapType?: MapType;
}

/** Where the map opens before the user searches for anything. */
export const DEFAULT_CENTER: GeoLocation = {
  label: 'Melbourne CBD',
  latitude: -37.8136,
  longitude: 144.9631,
};

export const DEFAULT_ZOOM = 14;
/** Zoom used when flying to a searched place. */
export const FOCUS_ZOOM = 15;

/** Street-level framing when selecting a shared location. */
export const LIVE_FOCUS_ZOOM = 16;
