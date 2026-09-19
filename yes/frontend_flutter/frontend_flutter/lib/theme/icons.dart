import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

/**
 * ELLY Maps icon registry.
 *
 * Icons come from `flutter_vector_icons`: Ionicons for the
 * clean outline navigation/UI glyphs, and MaterialCommunityIcons for the
 * filled service glyphs (ambulance, police, fire…). Each entry is mapped to
 * match the reference design (reference/Elly Maps Overview Design.jpeg).
 *
 * Usage:
 *   import '../components/Icon.dart';
 *   Icon(name: 'sos', size: 20, color: colors.emergency)
 */

typedef IconFamily = String;

class IconDef {
  final IconFamily family;
  /** Glyph name within the chosen family. */
  final IconData glyph;

  const IconDef({
    required this.family,
    required this.glyph,
  });
}

/** Named icons used across the app, keyed by intent (not by glyph). */
const Map<String, IconDef> ICONS = {
  // --- Bottom tab bar (the four systems) ---
  'tabMap': IconDef(family: 'ion', glyph: Ionicons.navigate),
  'tabConnections': IconDef(family: 'ion', glyph: Ionicons.people),
  'tabEmergency': IconDef(family: 'mci', glyph: MaterialCommunityIcons.shield_plus),
  'tabElly': IconDef(family: 'mci', glyph: MaterialCommunityIcons.creation),

  // --- Map / navigation ---
  'search': IconDef(family: 'ion', glyph: Ionicons.search),
  'voice': IconDef(family: 'ion', glyph: Ionicons.mic),
  'layers': IconDef(family: 'ion', glyph: Ionicons.layers),
  'locate': IconDef(family: 'ion', glyph: Ionicons.locate),
  'close': IconDef(family: 'ion', glyph: Ionicons.close),
  'route': IconDef(family: 'mci', glyph: MaterialCommunityIcons.routes),

  // arrows for the big turn card while navigating
  'turnLeft': IconDef(family: 'mci', glyph: MaterialCommunityIcons.arrow_left_top),
  'turnRight': IconDef(family: 'mci', glyph: MaterialCommunityIcons.arrow_right_top),
  'slightLeft': IconDef(family: 'mci', glyph: MaterialCommunityIcons.arrow_top_left),
  'slightRight': IconDef(family: 'mci', glyph: MaterialCommunityIcons.arrow_top_right),
  'straight': IconDef(family: 'mci', glyph: MaterialCommunityIcons.arrow_up),
  'uTurn': IconDef(family: 'mci', glyph: MaterialCommunityIcons.arrow_u_left_top),
  'roundabout': IconDef(family: 'mci', glyph: MaterialCommunityIcons.rotate_right),
  'arrive': IconDef(family: 'mci', glyph: MaterialCommunityIcons.map_marker_check),

  'car': IconDef(family: 'ion', glyph: Ionicons.car),
  'walk': IconDef(family: 'ion', glyph: Ionicons.walk),
  'cycle': IconDef(family: 'ion', glyph: Ionicons.bicycle),
  'pin': IconDef(family: 'ion', glyph: Ionicons.location),
  'star': IconDef(family: 'ion', glyph: Ionicons.star),
  'home': IconDef(family: 'ion', glyph: Ionicons.home),
  'work': IconDef(family: 'ion', glyph: Ionicons.briefcase),
  'calendar': IconDef(family: 'ion', glyph: Ionicons.calendar),
  'weather': IconDef(family: 'mci', glyph: MaterialCommunityIcons.weather_partly_cloudy),
  'rain': IconDef(family: 'mci', glyph: MaterialCommunityIcons.weather_pouring),
  'aqi': IconDef(family: 'mci', glyph: MaterialCommunityIcons.air_filter),
  'traffic': IconDef(family: 'mci', glyph: MaterialCommunityIcons.traffic_light),
  'parking': IconDef(family: 'mci', glyph: MaterialCommunityIcons.parking),
  'fuel': IconDef(family: 'mci', glyph: MaterialCommunityIcons.gas_station),
  'charging': IconDef(family: 'mci', glyph: MaterialCommunityIcons.ev_station),
  'restaurant': IconDef(family: 'ion', glyph: Ionicons.restaurant),
  'hotel': IconDef(family: 'ion', glyph: Ionicons.bed),
  'attraction': IconDef(family: 'ion', glyph: Ionicons.camera),

  // --- Connections ---
  'people': IconDef(family: 'ion', glyph: Ionicons.people),
  'profile': IconDef(family: 'ion', glyph: Ionicons.person),
  'addPerson': IconDef(family: 'ion', glyph: Ionicons.person_add),
  'group': IconDef(family: 'mci', glyph: MaterialCommunityIcons.account_group),
  'family': IconDef(family: 'mci', glyph: MaterialCommunityIcons.account_child),
  'team': IconDef(family: 'mci', glyph: MaterialCommunityIcons.briefcase_account),
  'safeArrival': IconDef(family: 'mci', glyph: MaterialCommunityIcons.shield_check),
  'history': IconDef(family: 'ion', glyph: Ionicons.time),
  'permissions': IconDef(family: 'ion', glyph: Ionicons.lock_closed),
  'liveShare': IconDef(family: 'ion', glyph: Ionicons.share_social),

  // --- Emergency ---
  'sos': IconDef(family: 'mci', glyph: MaterialCommunityIcons.alarm_light),
  'ambulance': IconDef(family: 'mci', glyph: MaterialCommunityIcons.ambulance),
  'police': IconDef(family: 'mci', glyph: MaterialCommunityIcons.police_badge),
  'fire': IconDef(family: 'mci', glyph: MaterialCommunityIcons.fire),
  'roadside': IconDef(family: 'mci', glyph: MaterialCommunityIcons.tow_truck),
  'shareLocation': IconDef(family: 'mci', glyph: MaterialCommunityIcons.crosshairs_gps),
  'contacts': IconDef(family: 'mci', glyph: MaterialCommunityIcons.card_account_phone),
  'hospital': IconDef(family: 'mci', glyph: MaterialCommunityIcons.hospital_building),
  'clinic': IconDef(family: 'mci', glyph: MaterialCommunityIcons.medical_bag),
  'pharmacy': IconDef(family: 'mci', glyph: MaterialCommunityIcons.pill),
  'bloodBank': IconDef(family: 'mci', glyph: MaterialCommunityIcons.blood_bag),
  'call': IconDef(family: 'ion', glyph: Ionicons.call),

  // --- ELLY AI ---
  'elly': IconDef(family: 'mci', glyph: MaterialCommunityIcons.creation),
  'send': IconDef(family: 'ion', glyph: Ionicons.send),
  'suggestion': IconDef(family: 'mci', glyph: MaterialCommunityIcons.lightbulb_on),
  'leaveNow': IconDef(family: 'ion', glyph: Ionicons.car_sport),
  'planTrip': IconDef(family: 'mci', glyph: MaterialCommunityIcons.map_search),
  'bestTime': IconDef(family: 'ion', glyph: Ionicons.time),
  'bell': IconDef(family: 'ion', glyph: Ionicons.notifications),
};

typedef IconName = String;