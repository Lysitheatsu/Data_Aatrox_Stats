import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/client.dart';

/**
 * Saved places, kept on the device.
 *
 * Covers recent destinations, favourites, and home & work. Uses localStorage
 * on web. Native would need AsyncStorage, which is a new dependency, so for
 * now it just keeps things in memory there and forgets on restart.
 */

const KEY = 'elly.savedPlaces.v1';
const MAX_RECENTS = 8;

class SavedPlaces {
  final List<GeoLocation> recents;
  final List<GeoLocation> favourites;
  final GeoLocation? home;
  final GeoLocation? work;

  const SavedPlaces({
    required this.recents,
    required this.favourites,
    required this.home,
    required this.work,
  });

  factory SavedPlaces.fromJson(Map<String, dynamic> json) {
    return SavedPlaces(
      recents: (json['recents'] as List? ?? [])
        .map((item) => GeoLocation.fromJson(item))
        .toList(),
      favourites: (json['favourites'] as List? ?? [])
        .map((item) => GeoLocation.fromJson(item))
        .toList(),
      home: json['home'] != null ? GeoLocation.fromJson(json['home']) : null,
      work: json['work'] != null ? GeoLocation.fromJson(json['work']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recents': recents.map((item) => item.toJson()).toList(),
      'favourites': favourites.map((item) => item.toJson()).toList(),
      'home': home?.toJson(),
      'work': work?.toJson(),
    };
  }
}

final EMPTY = SavedPlaces(recents: [], favourites: [], home: null, work: null);

// fallback for native, where there's no localStorage
SavedPlaces memory = EMPTY;

Future<SharedPreferences?> store() async {
  return kIsWeb ? SharedPreferences.getInstance() : null;
}

Future<SavedPlaces> load() async {
  final s = await store();
  if (s == null) return memory;
  try {
    final raw = s.getString(KEY);
    return raw != null ? SavedPlaces.fromJson(jsonDecode(raw)) : EMPTY;
  } catch (_) {
    // corrupt or unreadable, start fresh rather than crash
    return EMPTY;
  }
}

Future<void> save(SavedPlaces places) async {
  final s = await store();
  memory = places;
  if (s == null) return;
  try {
    await s.setString(KEY, jsonEncode(places.toJson()));
  } catch (_) {
    // out of space or private mode, not worth breaking the app over
  }
}

/** Two places are the same place if they're at the same coordinates. */
bool isSame(GeoLocation? a, GeoLocation? b) {
  if (a == null || b == null) return false;
  return a.latitude == b.latitude && a.longitude == b.longitude;
}

/** Add somewhere you just went to the top of the recents list. */
SavedPlaces addRecent(SavedPlaces places, GeoLocation place) {
  final withoutDuplicate = places.recents.where((p) => !isSame(p, place)).toList();
  return SavedPlaces(
    recents: [place, ...withoutDuplicate].take(MAX_RECENTS).toList(),
    favourites: places.favourites,
    home: places.home,
    work: places.work,
  );
}

/** Star or unstar a place. */
SavedPlaces toggleFavourite(SavedPlaces places, GeoLocation place) {
  final already = places.favourites.any((p) => isSame(p, place));
  return SavedPlaces(
    recents: places.recents,
    favourites: already
      ? places.favourites.where((p) => !isSame(p, place)).toList()
      : [place, ...places.favourites],
    home: places.home,
    work: places.work,
  );
}

bool isFavourite(SavedPlaces places, GeoLocation? place) {
  return place != null && places.favourites.any((p) => isSame(p, place));
}

/** Set home or work to a place, or pass null to clear it. */
SavedPlaces setHomeOrWork(
  SavedPlaces places,
  String which,
  GeoLocation? place,
) {
  return SavedPlaces(
    recents: places.recents,
    favourites: places.favourites,
    home: which == 'home' ? place : places.home,
    work: which == 'work' ? place : places.work,
  );
}