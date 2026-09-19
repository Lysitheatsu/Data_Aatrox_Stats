import type { GeoLocation } from '@/api/client';

/**
 * Saved places, kept on the device.
 *
 * Covers recent destinations, favourites, and home & work. Uses localStorage
 * on web. Native would need AsyncStorage, which is a new dependency, so for
 * now it just keeps things in memory there and forgets on restart.
 */

const KEY = 'elly.savedPlaces.v1';
const MAX_RECENTS = 8;

export interface SavedPlaces {
  recents: GeoLocation[];
  favourites: GeoLocation[];
  home: GeoLocation | null;
  work: GeoLocation | null;
}

export const EMPTY: SavedPlaces = { recents: [], favourites: [], home: null, work: null };

// fallback for native, where there's no localStorage
let memory: SavedPlaces = EMPTY;

function store(): Storage | null {
  return typeof localStorage === 'undefined' ? null : localStorage;
}

export function load(): SavedPlaces {
  const s = store();
  if (!s) return memory;
  try {
    const raw = s.getItem(KEY);
    return raw ? { ...EMPTY, ...JSON.parse(raw) } : EMPTY;
  } catch {
    // corrupt or unreadable, start fresh rather than crash
    return EMPTY;
  }
}

export function save(places: SavedPlaces): void {
  const s = store();
  memory = places;
  if (!s) return;
  try {
    s.setItem(KEY, JSON.stringify(places));
  } catch {
    // out of space or private mode, not worth breaking the app over
  }
}

/** Two places are the same place if they're at the same coordinates. */
export function isSame(a: GeoLocation | null, b: GeoLocation | null): boolean {
  if (!a || !b) return false;
  return a.latitude === b.latitude && a.longitude === b.longitude;
}

/** Add somewhere you just went to the top of the recents list. */
export function addRecent(places: SavedPlaces, place: GeoLocation): SavedPlaces {
  const withoutDuplicate = places.recents.filter((p) => !isSame(p, place));
  return { ...places, recents: [place, ...withoutDuplicate].slice(0, MAX_RECENTS) };
}

/** Star or unstar a place. */
export function toggleFavourite(places: SavedPlaces, place: GeoLocation): SavedPlaces {
  const already = places.favourites.some((p) => isSame(p, place));
  return {
    ...places,
    favourites: already
      ? places.favourites.filter((p) => !isSame(p, place))
      : [place, ...places.favourites],
  };
}

export function isFavourite(places: SavedPlaces, place: GeoLocation | null): boolean {
  return !!place && places.favourites.some((p) => isSame(p, place));
}

/** Set home or work to a place, or pass null to clear it. */
export function setHomeOrWork(
  places: SavedPlaces,
  which: 'home' | 'work',
  place: GeoLocation | null,
): SavedPlaces {
  return { ...places, [which]: place };
}
