/**
 * Thin client for the ELLY Maps backend (FastAPI).
 *
 * Set EXPO_PUBLIC_API_URL in your environment to point at the backend;
 * In a browser, the default uses the same hostname as the frontend with the
 * backend port. This works for localhost, Tailscale IPs, and MagicDNS names.
 */
import 'dart:convert';
import 'package:http/http.dart' as http;

String defaultApiUrl() {
  final browserLocation = Uri.base;
  if (browserLocation.host.isNotEmpty) {
    final host = browserLocation.host.contains(':')
      ? '[${browserLocation.host}]'
      : browserLocation.host;
    return 'http://$host:8000';
  }
  return 'http://localhost:8000';
}

final String API_BASE_URL =
  const String.fromEnvironment('EXPO_PUBLIC_API_URL').isNotEmpty
    ? const String.fromEnvironment('EXPO_PUBLIC_API_URL')
    : defaultApiUrl();

class ApiError extends Error {
  final int status;
  final String responseBody;
  final String name = 'ApiError';

  ApiError(this.status, this.responseBody);

  @override
  String toString() {
    return 'ELLY API $status: $responseBody';
  }
}

Future<T> request<T>(
  String path, {
  String method = 'GET',
  String? body,
  T Function(dynamic json)? fromJson,
}) async {
  final req = http.Request(method, Uri.parse('$API_BASE_URL$path'));
  req.headers.addAll({ 'Content-Type': 'application/json' });
  if (body != null) req.body = body;

  final streamedRes = await req.send();
  final res = await http.Response.fromStream(streamedRes);

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw ApiError(res.statusCode, res.body);
  }

  final json = jsonDecode(res.body);

  if (fromJson != null) {
    return fromJson(json);
  }

  return json as T;
}

class Suggestion {
  final String type;
  final String title;
  final String detail;

  Suggestion({
    required this.type,
    required this.title,
    required this.detail,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      type: json['type'],
      title: json['title'],
      detail: json['detail'],
    );
  }
}

// ── Maps (Module 1) ─────────────────────────────────────────────────────────
// These call the /maps endpoints on the backend.

/** A point on the map. Same shape as GeoLocation on the backend. */
class GeoLocation {
  String? label;
  String? address;
  double latitude;
  double longitude;

  GeoLocation({
    this.label,
    this.address,
    required this.latitude,
    required this.longitude,
  });

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      label: json['label'],
      address: json['address'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

typedef TravelMode = String;

class RouteStep {
  final String instruction;
  final double distance_m;
  final String? road;
  /** [lon, lat] position of the turn. */
  final List<double>? location;

  RouteStep({
    required this.instruction,
    required this.distance_m,
    this.road,
    this.location,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instruction: json['instruction'],
      distance_m: (json['distance_m'] as num).toDouble(),
      road: json['road'],
      location: json['location'] != null
        ? (json['location'] as List).map((value) => (value as num).toDouble()).toList()
        : null,
    );
  }
}

class RouteOption {
  final String summary;
  final double distance_km;
  final int eta_minutes;
  final bool has_tolls;
  /** True when the time is an estimate, so show "about 31 min". */
  final bool eta_is_estimated;
  /** [lon, lat] pairs to draw on the map. Note the order. */
  final List<List<double>> geometry;
  /** Turn-by-turn directions returned by the routing service. */
  final List<RouteStep> steps;

  RouteOption({
    required this.summary,
    required this.distance_km,
    required this.eta_minutes,
    required this.has_tolls,
    required this.eta_is_estimated,
    required this.geometry,
    required this.steps,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      summary: json['summary'],
      distance_km: (json['distance_km'] as num).toDouble(),
      eta_minutes: (json['eta_minutes'] as num).toInt(),
      has_tolls: json['has_tolls'],
      eta_is_estimated: json['eta_is_estimated'],
      geometry: (json['geometry'] as List)
        .map((point) => (point as List).map((value) => (value as num).toDouble()).toList())
        .toList(),
      steps: (json['steps'] as List)
        .map((step) => RouteStep.fromJson(step))
        .toList(),
    );
  }
}

class RouteResponse {
  final TravelMode mode;
  final List<RouteOption> options;

  RouteResponse({
    required this.mode,
    required this.options,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    return RouteResponse(
      mode: json['mode'],
      options: (json['options'] as List)
        .map((option) => RouteOption.fromJson(option))
        .toList(),
    );
  }
}

/** The categories you can search for. */
typedef NearbyCategory = String;

class NearbyPlace {
  final String name;
  final NearbyCategory category;
  final double distance_km;
  final GeoLocation location;

  NearbyPlace({
    required this.name,
    required this.category,
    required this.distance_km,
    required this.location,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      name: json['name'],
      category: json['category'],
      distance_km: (json['distance_km'] as num).toDouble(),
      location: GeoLocation.fromJson(json['location']),
    );
  }
}

/** Roughly what the fuel costs. An estimate, not a real price. */
class FuelEstimate {
  final double cost;
  final double? litres;
  final double consumption_per_100km;
  final double price_per_unit;
  final String unit;

  FuelEstimate({
    required this.cost,
    required this.litres,
    required this.consumption_per_100km,
    required this.price_per_unit,
    required this.unit,
  });

  factory FuelEstimate.fromJson(Map<String, dynamic> json) {
    return FuelEstimate(
      cost: (json['cost'] as num).toDouble(),
      litres: json['litres'] != null ? (json['litres'] as num).toDouble() : null,
      consumption_per_100km: (json['consumption_per_100km'] as num).toDouble(),
      price_per_unit: (json['price_per_unit'] as num).toDouble(),
      unit: json['unit'],
    );
  }
}

class ChargingStop {
  final String name;
  final double distance_km;

  ChargingStop({
    required this.name,
    required this.distance_km,
  });

  factory ChargingStop.fromJson(Map<String, dynamic> json) {
    return ChargingStop(
      name: json['name'],
      distance_km: (json['distance_km'] as num).toDouble(),
    );
  }
}

class ChargingPlan {
  final int stops_needed;
  final double assumed_range_km;
  final List<ChargingStop> chargers;

  ChargingPlan({
    required this.stops_needed,
    required this.assumed_range_km,
    required this.chargers,
  });

  factory ChargingPlan.fromJson(Map<String, dynamic> json) {
    return ChargingPlan(
      stops_needed: (json['stops_needed'] as num).toInt(),
      assumed_range_km: (json['assumed_range_km'] as num).toDouble(),
      chargers: (json['chargers'] as List)
        .map((charger) => ChargingStop.fromJson(charger))
        .toList(),
    );
  }
}

class JourneyInfo {
  final String weather_summary;
  final int? air_quality_index;
  /** Null for now, we have no traffic data source yet. */
  final int? traffic_delay_minutes;
  final double? estimated_fuel_cost;
  final FuelEstimate? fuel;
  final FuelEstimate? ev;
  /** Tolls and roadworks on the route, from OSM. */
  final List<String> toll_roads;
  final List<String> construction;
  final ChargingPlan? charging;

  JourneyInfo({
    required this.weather_summary,
    required this.air_quality_index,
    required this.traffic_delay_minutes,
    required this.estimated_fuel_cost,
    required this.fuel,
    required this.ev,
    required this.toll_roads,
    required this.construction,
    required this.charging,
  });

  factory JourneyInfo.fromJson(Map<String, dynamic> json) {
    return JourneyInfo(
      weather_summary: json['weather_summary'],
      air_quality_index: json['air_quality_index'] != null ? (json['air_quality_index'] as num).toInt() : null,
      traffic_delay_minutes: json['traffic_delay_minutes'] != null ? (json['traffic_delay_minutes'] as num).toInt() : null,
      estimated_fuel_cost: json['estimated_fuel_cost'] != null ? (json['estimated_fuel_cost'] as num).toDouble() : null,
      fuel: json['fuel'] != null ? FuelEstimate.fromJson(json['fuel']) : null,
      ev: json['ev'] != null ? FuelEstimate.fromJson(json['ev']) : null,
      toll_roads: List<String>.from(json['toll_roads']),
      construction: List<String>.from(json['construction']),
      charging: json['charging'] != null ? ChargingPlan.fromJson(json['charging']) : null,
    );
  }
}

class Api {
  Future<Map<String, dynamic>> health() =>
    request<Map<String, dynamic>>(
      '/health',
      fromJson: (json) => Map<String, dynamic>.from(json),
    );

  Future<List<Suggestion>> suggestions(String userId) =>
    request<List<Suggestion>>(
      '/assistant/suggestions?user_id=$userId',
      fromJson: (json) => (json as List)
        .map((item) => Suggestion.fromJson(item))
        .toList(),
    );

  /** Search for a place by name, for the search bar. */
  Future<List<GeoLocation>> searchPlaces(String query, [int limit = 5, double? latitude, double? longitude]) =>
    request<List<GeoLocation>>(
      '/maps/search?q=${Uri.encodeQueryComponent(query)}&limit=$limit' +
        '${latitude != null ? '&latitude=$latitude' : ''}' +
        '${longitude != null ? '&longitude=$longitude' : ''}',
      fromJson: (json) => (json as List)
        .map((item) => GeoLocation.fromJson(item))
        .toList(),
    );

  /** Plan a route between two points. */
  Future<RouteResponse> planRoutes(
    GeoLocation origin,
    GeoLocation destination, [
    TravelMode mode = 'driving',
  ]) =>
    request<RouteResponse>(
      '/maps/routes',
      method: 'POST',
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'mode': mode,
      }),
      fromJson: (json) => RouteResponse.fromJson(json),
    );

  /** Find places nearby, closest first. */
  Future<List<NearbyPlace>> nearby(
    NearbyCategory category,
    double latitude,
    double longitude, [
    int radiusM = 2000,
  ]) =>
    request<List<NearbyPlace>>(
      '/maps/nearby?category=$category&latitude=$latitude' +
        '&longitude=$longitude&radius_m=$radiusM',
      fromJson: (json) => (json as List)
        .map((item) => NearbyPlace.fromJson(item))
        .toList(),
    );

  /**
   * Weather and air quality for the chip. Pass the distance and route too
   * and you also get fuel cost, tolls and roadworks back.
   */
  Future<JourneyInfo> journeyInfo(
    GeoLocation origin,
    GeoLocation destination, [
    double? distanceKm,
    List<List<double>>? geometry,
  ]) =>
    request<JourneyInfo>(
      '/maps/journey-info${distanceKm != null && distanceKm != 0 ? '?distance_km=$distanceKm' : ''}',
      method: 'POST',
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'geometry': geometry ?? [],
      }),
      fromJson: (json) => JourneyInfo.fromJson(json),
    );
}

final api = Api();

/** SOS & Emergency */

Future<dynamic> dispatchSos(
  String userId,
  double latitude,
  double longitude,
) {
  final id = DateTime.now().millisecondsSinceEpoch.toString();

  final data = {
    'packet_id': 'packet_$id',
    'session_id': 'session_$id',
    'user_id': userId,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'packet_version': '2.0',
    'sequence_number': 1,
    'status': 'QUEUED',
    'priority': 'CRITICAL',
    'packet_hash': 'manual_$id',
    'packet_checksum': 'manual_$id',

    'location': {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': 0,
    },

    'transcript': {
      'text': 'Manual SOS button pressed',
      'confidence': 1,
      'language': 'en',
      'is_partial': false,
      'speech_probability': 1,
      'parsed_intent': 'EMERGENCY',
      'matched_keywords': ['SOS'],
    },
  };

  return request<dynamic>(
    '/v1/emergency/dispatch',
    method: 'POST',
    body: jsonEncode(data),
  );
}

Future<dynamic> getSosCircle(String userId) {
  final url = '/v1/sos-circle/$userId/contacts';

  return request<dynamic>(url);
}

Future<dynamic> getHealthPassport(String userId) {
  final url = '/v1/health-passport/$userId';

  return request<dynamic>(url);
}

Future<dynamic> getNearbyResponders(
  double latitude,
  double longitude,
) {
  final url =
    '/v1/responders/nearby?lat=$latitude&lng=$longitude';

  return request<dynamic>(url);
}