import 'dart:async';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import '../api/client.dart';

/**
 * Follows the user's location while they're navigating.
 *
 * The normal useCurrentLocation hook asks once. This one keeps watching, so
 * the dot moves as you drive. Only turn it on during navigation, it uses a
 * lot of battery.
 *
 * Web only. Native would need platform location permission setup.
 */

class LivePosition {
  final GeoLocation location;
  /** Which way you're facing, 0-360. Null if the phone can't tell. */
  final double? heading;
  /** Metres per second. Null if unknown. */
  final double? speed;

  const LivePosition({
    required this.location,
    this.heading,
    this.speed,
  });
}

LivePosition? useLiveLocation(bool active) {
  final position = useState<LivePosition?>(null);
  final watchId = useRef<StreamSubscription<Position>?>(null);

  useEffect(() {
    if (!active) {
      position.value = null;
      return null;
    }

    watchId.value = Geolocator.getPositionStream(
      locationSettings: WebSettings(
        accuracy: LocationAccuracy.high,
        maximumAge: const Duration(milliseconds: 2000),
        timeLimit: const Duration(seconds: 10),
      ),
    ).listen(
      (reading) {
        position.value = LivePosition(
          location: GeoLocation(
            label: 'You',
            latitude: reading.latitude,
            longitude: reading.longitude,
          ),
          heading: reading.heading,
          speed: reading.speed,
        );
      },
      onError: (_) {
        // they said no, or the phone can't get a fix. keep the last position.
      },
    );

    return () {
      if (watchId.value != null) {
        watchId.value!.cancel();
        watchId.value = null;
      }
    };
  }, [active]);

  return position.value;
}