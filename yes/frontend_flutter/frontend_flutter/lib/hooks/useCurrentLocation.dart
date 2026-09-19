import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import '../api/client.dart';

/**
 * Gets the user's location from the browser.
 *
 * If they say no we fall back to Melbourne CBD so routes still work.
 * Web only for now, native would need location permission setup.
 */

// used until we know better, and if the user says no
final FALLBACK_LOCATION = GeoLocation(
  label: 'Melbourne CBD',
  latitude: -37.8136,
  longitude: 144.9631,
);

typedef LocationStatus = String;

class Result {
  final GeoLocation location;
  final LocationStatus status;

  const Result({
    required this.location,
    required this.status,
  });
}

Result useCurrentLocation() {
  final location = useState<GeoLocation>(FALLBACK_LOCATION);
  final status = useState<LocationStatus>('locating');

  useEffect(() {
    // this doesn't exist without location permission
    bool cancelled = false;

    Future<void> getCurrentPosition() async {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (!cancelled) status.value = 'fallback';
          return;
        }

        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!cancelled) status.value = 'fallback';
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: WebSettings(
            accuracy: LocationAccuracy.high,
            maximumAge: Duration(minutes: 1),
            timeLimit: Duration(seconds: 4),
          ),
        );

        if (cancelled) return;
        location.value = GeoLocation(
          label: 'Your location',
          latitude: position.latitude,
          longitude: position.longitude,
        );
        status.value = 'precise';
      } catch (_) {
        // said no, or it timed out. keep the fallback.
        if (!cancelled) status.value = 'fallback';
      }
    }

    getCurrentPosition();

    return () {
      cancelled = true;
    };
  }, const []);

  return Result(location: location.value, status: status.value);
}