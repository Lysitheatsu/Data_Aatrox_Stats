import { useEffect, useState } from 'react';
import type { GeoLocation } from '@/api/client';

/**
 * Gets the user's location from the browser.
 *
 * If they say no we fall back to Melbourne CBD so routes still work.
 * Web only for now, native would need expo-location.
 */

// used until we know better, and if the user says no
export const FALLBACK_LOCATION: GeoLocation = {
  label: 'Melbourne CBD',
  latitude: -37.8136,
  longitude: 144.9631,
};

export type LocationStatus = 'locating' | 'precise' | 'fallback';

interface Result {
  location: GeoLocation;
  status: LocationStatus;
}

export function useCurrentLocation(): Result {
  const [location, setLocation] = useState<GeoLocation>(FALLBACK_LOCATION);
  const [status, setStatus] = useState<LocationStatus>('locating');

  useEffect(() => {
    // this doesn't exist on native
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setStatus('fallback');
      return;
    }

    let cancelled = false;

    navigator.geolocation.getCurrentPosition(
      (position) => {
        if (cancelled) return;
        setLocation({
          label: 'Your location',
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        });
        setStatus('precise');
      },
      () => {
        // said no, or it timed out. keep the fallback.
        if (!cancelled) setStatus('fallback');
      },
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 60_000 },
    );

    return () => {
      cancelled = true;
    };
  }, []);

  return { location, status };
}
