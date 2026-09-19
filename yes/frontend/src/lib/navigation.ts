import type { GeoLocation, RouteStep } from '@/api/client';
import type { IconName } from '@/theme/icons';

/**
 * The maths behind live navigation.
 *
 * Works out how far you are from the next turn so the app can move on by
 * itself, and how far off the route you've drifted so it knows when you've
 * gone the wrong way.
 */

/** How close you have to get before we call the turn done. */
export const ARRIVED_AT_TURN_M = 30;

/** How far off the line before we say you've gone off route. */
export const OFF_ROUTE_M = 60;

/**
 * How far you have to move before we trust the direction you're going.
 * Below this it's mostly gps wobble, not you actually turning.
 */
export const BEARING_MIN_MOVE_M = 8;

/** Distance between two points in metres. */
export function distanceM(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const earthRadius = 6371000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return Math.round(earthRadius * 2 * Math.asin(Math.sqrt(a)));
}

/** How far you are from a step's turn. Null if the step has no coordinates. */
export function distanceToStep(here: GeoLocation, step: RouteStep): number | null {
  if (!step.location) return null;
  const [lon, lat] = step.location;
  return distanceM(here.latitude, here.longitude, lat, lon);
}

/** Have you reached this turn yet? */
export function hasReachedStep(here: GeoLocation, step: RouteStep): boolean {
  const away = distanceToStep(here, step);
  return away !== null && away <= ARRIVED_AT_TURN_M;
}

/**
 * How far you are from the route line.
 *
 * Checks the distance to the nearest point on the route. Not perfectly
 * accurate since it only looks at the points, not the lines between them,
 * but the points are close enough together that it's fine.
 */
export function distanceFromRoute(
  here: GeoLocation,
  geometry: [number, number][],
): number | null {
  if (!geometry.length) return null;
  let closest = Infinity;
  for (const [lon, lat] of geometry) {
    const away = distanceM(here.latitude, here.longitude, lat, lon);
    if (away < closest) closest = away;
  }
  return closest;
}

/**
 * The bit of the route you still have to travel.
 *
 * Finds the closest point on the line to you and throws away everything
 * behind it, so the line disappears as you go, like google maps does. If
 * you've wandered off we leave the whole thing alone, otherwise the line
 * would snap to some random far away point.
 */
export function remainingRoute(
  geometry: [number, number][],
  here: GeoLocation,
): [number, number][] {
  if (geometry.length === 0) return geometry;

  let closestIndex = 0;
  let closest = Infinity;
  for (let i = 0; i < geometry.length; i++) {
    const [lon, lat] = geometry[i];
    const away = distanceM(here.latitude, here.longitude, lat, lon);
    if (away < closest) {
      closest = away;
      closestIndex = i;
    }
  }

  if (closest > OFF_ROUTE_M) return geometry;

  // start the line at you rather than at the point you last went past
  return [[here.longitude, here.latitude], ...geometry.slice(closestIndex + 1)];
}

/** Have you wandered off the route? */
export function isOffRoute(
  here: GeoLocation,
  geometry: [number, number][],
): boolean {
  const away = distanceFromRoute(here, geometry);
  return away !== null && away > OFF_ROUTE_M;
}

/**
 * Pick the arrow to show for a turn.
 *
 * The backend only gives us the instruction as words, not a turn type, so we
 * just read the text. Order matters, "slight left" has to be checked before
 * plain "left" or it'd never match.
 */
export function turnIcon(instruction: string): IconName {
  const words = instruction.toLowerCase();
  if (words.includes('u-turn')) return 'uTurn';
  if (words.includes('arrive') || words.includes('destination')) return 'arrive';
  if (words.includes('roundabout') || words.includes('exit the')) return 'roundabout';
  if (words.includes('slight left') || words.includes('keep left')) return 'slightLeft';
  if (words.includes('slight right') || words.includes('keep right')) return 'slightRight';
  if (words.includes('left')) return 'turnLeft';
  if (words.includes('right')) return 'turnRight';
  return 'straight';
}

/** Metres still to go, counting the turn you're heading to and everything after. */
export function remainingDistanceM(steps: RouteStep[], fromIndex: number): number {
  return steps
    .slice(fromIndex)
    .reduce((total, step) => total + (step.distance_m ?? 0), 0);
}

/** Which way you're heading, for turning the map. */
export function bearingBetween(from: GeoLocation, to: GeoLocation): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const toDeg = (rad: number) => (rad * 180) / Math.PI;
  const dLon = toRad(to.longitude - from.longitude);
  const y = Math.sin(dLon) * Math.cos(toRad(to.latitude));
  const x =
    Math.cos(toRad(from.latitude)) * Math.sin(toRad(to.latitude)) -
    Math.sin(toRad(from.latitude)) * Math.cos(toRad(to.latitude)) * Math.cos(dLon);
  // +360 % 360 so we get 0-359 rather than -180 to 180
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}
