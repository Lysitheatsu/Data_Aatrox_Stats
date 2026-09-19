import 'dart:math' as math;
import '../api/client.dart';
import '../theme/icons.dart';

/**
 * The maths behind live navigation.
 *
 * Works out how far you are from the next turn so the app can move on by
 * itself, and how far off the route you've drifted so it knows when you've
 * gone the wrong way.
 */

/** How close you have to get before we call the turn done. */
const ARRIVED_AT_TURN_M = 30;

/** How far off the line before we say you've gone off route. */
const OFF_ROUTE_M = 60;

/**
 * How far you have to move before we trust the direction you're going.
 * Below this it's mostly gps wobble, not you actually turning.
 */
const BEARING_MIN_MOVE_M = 8;

/** Distance between two points in metres. */
double distanceM(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000;
  final toRad = (double deg) => (deg * math.pi) / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a =
    math.pow(math.sin(dLat / 2), 2) +
    math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return (earthRadius * 2 * math.asin(math.sqrt(a))).roundToDouble();
}

/** How far you are from a step's turn. Null if the step has no coordinates. */
double? distanceToStep(GeoLocation here, RouteStep step) {
  if (step.location == null) return null;
  final lon = step.location![0];
  final lat = step.location![1];
  return distanceM(here.latitude, here.longitude, lat, lon);
}

/** Have you reached this turn yet? */
bool hasReachedStep(GeoLocation here, RouteStep step) {
  final away = distanceToStep(here, step);
  return away != null && away <= ARRIVED_AT_TURN_M;
}

/**
 * How far you are from the route line.
 *
 * Checks the distance to the nearest point on the route. Not perfectly
 * accurate since it only looks at the points, not the lines between them,
 * but the points are close enough together that it's fine.
 */
double? distanceFromRoute(
  GeoLocation here,
  List<List<double>> geometry,
) {
  if (geometry.isEmpty) return null;
  double closest = double.infinity;
  for (final point in geometry) {
    final lon = point[0];
    final lat = point[1];
    final away = distanceM(here.latitude, here.longitude, lat, lon);
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
List<List<double>> remainingRoute(
  List<List<double>> geometry,
  GeoLocation here,
) {
  if (geometry.isEmpty) return geometry;

  int closestIndex = 0;
  double closest = double.infinity;
  for (int i = 0; i < geometry.length; i++) {
    final lon = geometry[i][0];
    final lat = geometry[i][1];
    final away = distanceM(here.latitude, here.longitude, lat, lon);
    if (away < closest) {
      closest = away;
      closestIndex = i;
    }
  }

  if (closest > OFF_ROUTE_M) return geometry;

  // start the line at you rather than at the point you last went past
  return [[here.longitude, here.latitude], ...geometry.sublist(closestIndex + 1)];
}

/** Have you wandered off the route? */
bool isOffRoute(
  GeoLocation here,
  List<List<double>> geometry,
) {
  final away = distanceFromRoute(here, geometry);
  return away != null && away > OFF_ROUTE_M;
}

/**
 * Pick the arrow to show for a turn.
 *
 * The backend only gives us the instruction as words, not a turn type, so we
 * just read the text. Order matters, "slight left" has to be checked before
 * plain "left" or it'd never match.
 */
IconName turnIcon(String instruction) {
  final words = instruction.toLowerCase();
  if (words.contains('u-turn')) return 'uTurn';
  if (words.contains('arrive') || words.contains('destination')) return 'arrive';
  if (words.contains('roundabout') || words.contains('exit the')) return 'roundabout';
  if (words.contains('slight left') || words.contains('keep left')) return 'slightLeft';
  if (words.contains('slight right') || words.contains('keep right')) return 'slightRight';
  if (words.contains('left')) return 'turnLeft';
  if (words.contains('right')) return 'turnRight';
  return 'straight';
}

/** Metres still to go, counting the turn you're heading to and everything after. */
double remainingDistanceM(List<RouteStep> steps, int fromIndex) {
  return steps
    .skip(fromIndex)
    .fold(0.0, (total, step) => total + step.distance_m);
}

/** Which way you're heading, for turning the map. */
double bearingBetween(GeoLocation from, GeoLocation to) {
  final toRad = (double deg) => (deg * math.pi) / 180;
  final toDeg = (double rad) => (rad * 180) / math.pi;
  final dLon = toRad(to.longitude - from.longitude);
  final y = math.sin(dLon) * math.cos(toRad(to.latitude));
  final x =
    math.cos(toRad(from.latitude)) * math.sin(toRad(to.latitude)) -
    math.sin(toRad(from.latitude)) * math.cos(toRad(to.latitude)) * math.cos(dLon);
  // +360 % 360 so we get 0-359 rather than -180 to 180
  return (toDeg(math.atan2(y, x)) + 360) % 360;
}