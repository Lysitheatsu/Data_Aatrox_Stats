import { useEffect, useRef, useState } from 'react';
import type { GeoLocation } from '@/api/client';

/**
 * Follows the user's location while they're navigating.
 *
 * The normal useCurrentLocation hook asks once. This one keeps watching, so
 * the dot moves as you drive. Only turn it on during navigation, it uses a
 * lot of battery.
 *
 * Web only. Native would need expo-location.
 */

export interface LivePosition {
  location: GeoLocation;
  /** Which way you're facing, 0-360. Null if the phone can't tell. */
  heading: number | null;
  /** Metres per second. Null if unknown. */
  speed: number | null;
}

export function useLiveLocation(active: boolean): LivePosition | null {
  const [position, setPosition] = useState<LivePosition | null>(null);
  const watchId = useRef<number | null>(null);

  useEffect(() => {
    if (!active || typeof navigator === 'undefined' || !navigator.geolocation) {
      setPosition(null);
      return;
    }

    watchId.current = navigator.geolocation.watchPosition(
      (reading) => {
        setPosition({
          location: {
            label: 'You',
            latitude: reading.coords.latitude,
            longitude: reading.coords.longitude,
          },
          heading: reading.coords.heading,
          speed: reading.coords.speed,
        });
      },
      () => {
        // they said no, or the phone can't get a fix. keep the last position.
      },
      { enableHighAccuracy: true, maximumAge: 2000, timeout: 10_000 },
    );

    return () => {
      if (watchId.current !== null) {
        navigator.geolocation.clearWatch(watchId.current);
        watchId.current = null;
      }
    };
  }, [active]);

  return position;
}
