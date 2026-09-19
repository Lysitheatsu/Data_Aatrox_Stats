/**
 * Thin client for the ELLY Maps backend (FastAPI).
 *
 * Set EXPO_PUBLIC_API_URL in your environment to point at the backend;
 * In a browser, the default uses the same hostname as the frontend with the
 * backend port. This works for localhost, Tailscale IPs, and MagicDNS names.
 */
function defaultApiUrl(): string {
  const browserLocation = typeof window !== 'undefined' ? window.location : undefined;
  if (browserLocation?.hostname) {
    const host = browserLocation.hostname.includes(':')
      ? `[${browserLocation.hostname}]`
      : browserLocation.hostname;
    return `http://${host}:8000`;
  }
  return 'http://localhost:8000';
}

export const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? defaultApiUrl();

export class ApiError extends Error {
  constructor(public readonly status: number, public readonly responseBody: string) {
    super(`ELLY API ${status}: ${responseBody}`);
    this.name = 'ApiError';
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });

  if (!res.ok) {
    throw new ApiError(res.status, await res.text());
  }

  return res.json() as Promise<T>;
}

export interface Suggestion {
  type: string;
  title: string;
  detail: string;
}

// ── Maps (Module 1) ─────────────────────────────────────────────────────────
// These call the /maps endpoints on the backend.

/** A point on the map. Same shape as GeoLocation on the backend. */
export interface GeoLocation {
  label?: string | null;
  address?: string | null;
  latitude: number;
  longitude: number;
}

export type TravelMode = 'driving' | 'walking' | 'cycling';

export interface RouteStep {
  instruction: string;
  distance_m: number;
  road?: string | null;
  /** [lon, lat] position of the turn. */
  location?: [number, number] | null;
}

export interface RouteOption {
  summary: string;
  distance_km: number;
  eta_minutes: number;
  has_tolls: boolean;
  /** True when the time is an estimate, so show "about 31 min". */
  eta_is_estimated: boolean;
  /** [lon, lat] pairs to draw on the map. Note the order. */
  geometry: [number, number][];
  /** Turn-by-turn directions returned by the routing service. */
  steps: RouteStep[];
}

export interface RouteResponse {
  mode: TravelMode;
  options: RouteOption[];
}

/** The categories you can search for. */
export type NearbyCategory =
  | 'restaurants'
  | 'hospitals'
  | 'pharmacies'
  | 'petrol_stations'
  | 'parking'
  | 'charging_stations'
  | 'hotels'
  | 'attractions';

export interface NearbyPlace {
  name: string;
  category: NearbyCategory;
  distance_km: number;
  location: GeoLocation;
}

/** Roughly what the fuel costs. An estimate, not a real price. */
export interface FuelEstimate {
  cost: number;
  litres: number | null;
  consumption_per_100km: number;
  price_per_unit: number;
  unit: string;
}

export interface ChargingStop {
  name: string;
  distance_km: number;
}

export interface ChargingPlan {
  stops_needed: number;
  assumed_range_km: number;
  chargers: ChargingStop[];
}

export interface JourneyInfo {
  weather_summary: string;
  air_quality_index: number | null;
  /** Null for now, we have no traffic data source yet. */
  traffic_delay_minutes: number | null;
  estimated_fuel_cost: number | null;
  fuel: FuelEstimate | null;
  ev: FuelEstimate | null;
  /** Tolls and roadworks on the route, from OSM. */
  toll_roads: string[];
  construction: string[];
  charging: ChargingPlan | null;
}

export const api = {
  health: () => request<{ status: string }>('/health'),

  suggestions: (userId: string) =>
    request<Suggestion[]>(
      `/assistant/suggestions?user_id=${userId}`
    ),

  /** Search for a place by name, for the search bar. */
  searchPlaces: (query: string, limit = 5, latitude?: number, longitude?: number) =>
    request<GeoLocation[]>(
      `/maps/search?q=${encodeURIComponent(query)}&limit=${limit}` +
        `${latitude !== undefined ? `&latitude=${latitude}` : ''}` +
        `${longitude !== undefined ? `&longitude=${longitude}` : ''}`,
    ),

  /** Plan a route between two points. */
  planRoutes: (
    origin: GeoLocation,
    destination: GeoLocation,
    mode: TravelMode = 'driving',
  ) =>
    request<RouteResponse>('/maps/routes', {
      method: 'POST',
      body: JSON.stringify({
        origin,
        destination,
        mode,
      }),
    }),

  /** Find places nearby, closest first. */
  nearby: (
    category: NearbyCategory,
    latitude: number,
    longitude: number,
    radiusM = 2000,
  ) =>
    request<NearbyPlace[]>(
      `/maps/nearby?category=${category}&latitude=${latitude}` +
        `&longitude=${longitude}&radius_m=${radiusM}`,
    ),

  /**
   * Weather and air quality for the chip. Pass the distance and route too
   * and you also get fuel cost, tolls and roadworks back.
   */
  journeyInfo: (
    origin: GeoLocation,
    destination: GeoLocation,
    distanceKm?: number,
    geometry?: [number, number][],
  ) =>
    request<JourneyInfo>(
      `/maps/journey-info${distanceKm ? `?distance_km=${distanceKm}` : ''}`,
      {
        method: 'POST',
        body: JSON.stringify({
          origin,
          destination,
          geometry: geometry ?? [],
        }),
      },
    ),
};

/** SOS & Emergency */

export function dispatchSos(
  userId: string,
  latitude: number,
  longitude: number,
) {
  const id = Date.now().toString();

  const data = {
    packet_id: `packet_${id}`,
    session_id: `session_${id}`,
    user_id: userId,
    generated_at: new Date().toISOString(),
    packet_version: '2.0',
    sequence_number: 1,
    status: 'QUEUED',
    priority: 'CRITICAL',
    packet_hash: `manual_${id}`,
    packet_checksum: `manual_${id}`,

    location: {
      latitude: latitude,
      longitude: longitude,
      accuracy: 0,
    },

    transcript: {
      text: 'Manual SOS button pressed',
      confidence: 1,
      language: 'en',
      is_partial: false,
      speech_probability: 1,
      parsed_intent: 'EMERGENCY',
      matched_keywords: ['SOS'],
    },
  };

  return request('/v1/emergency/dispatch', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export function getSosCircle(userId: string) {
  const url = `/v1/sos-circle/${userId}/contacts`;

  return request(url);
}

export function getHealthPassport(userId: string) {
  const url = `/v1/health-passport/${userId}`;

  return request(url);
}

export function getNearbyResponders(
  latitude: number,
  longitude: number,
) {
  const url =
    `/v1/responders/nearby?lat=${latitude}&lng=${longitude}`;

  return request(url);
}