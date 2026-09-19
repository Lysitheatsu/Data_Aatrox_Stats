/**
 * ELLY Maps icon registry.
 *
 * Icons come from `@expo/vector-icons` (bundled with Expo): Ionicons for the
 * clean outline navigation/UI glyphs, and MaterialCommunityIcons for the
 * filled service glyphs (ambulance, police, fire…). Each entry is mapped to
 * match the reference design (reference/Elly Maps Overview Design.jpeg).
 *
 * Usage:
 *   import { Icon } from '@/components/Icon';
 *   <Icon name="sos" size={20} color={colors.emergency} />
 */

export type IconFamily = 'ion' | 'mci';

export interface IconDef {
  family: IconFamily;
  /** Glyph name within the chosen family. */
  glyph: string;
}

/** Named icons used across the app, keyed by intent (not by glyph). */
export const ICONS = {
  // --- Bottom tab bar (the four systems) ---
  tabMap: { family: 'ion', glyph: 'navigate' },
  tabConnections: { family: 'ion', glyph: 'people' },
  tabEmergency: { family: 'mci', glyph: 'shield-plus' },
  tabElly: { family: 'ion', glyph: 'sparkles' },

  // --- Map / navigation ---
  search: { family: 'ion', glyph: 'search' },
  voice: { family: 'ion', glyph: 'mic' },
  layers: { family: 'ion', glyph: 'layers' },
  locate: { family: 'ion', glyph: 'locate' },
  close: { family: 'ion', glyph: 'close' },
  route: { family: 'mci', glyph: 'routes' },

  // arrows for the big turn card while navigating
  turnLeft: { family: 'mci', glyph: 'arrow-left-top' },
  turnRight: { family: 'mci', glyph: 'arrow-right-top' },
  slightLeft: { family: 'mci', glyph: 'arrow-top-left' },
  slightRight: { family: 'mci', glyph: 'arrow-top-right' },
  straight: { family: 'mci', glyph: 'arrow-up' },
  uTurn: { family: 'mci', glyph: 'arrow-u-left-top' },
  roundabout: { family: 'mci', glyph: 'rotate-right' },
  arrive: { family: 'mci', glyph: 'map-marker-check' },

  car: { family: 'ion', glyph: 'car' },
  walk: { family: 'ion', glyph: 'walk' },
  cycle: { family: 'ion', glyph: 'bicycle' },
  pin: { family: 'ion', glyph: 'location' },
  star: { family: 'ion', glyph: 'star' },
  home: { family: 'ion', glyph: 'home' },
  work: { family: 'ion', glyph: 'briefcase' },
  calendar: { family: 'ion', glyph: 'calendar' },
  weather: { family: 'mci', glyph: 'weather-partly-cloudy' },
  rain: { family: 'mci', glyph: 'weather-pouring' },
  aqi: { family: 'mci', glyph: 'air-filter' },
  traffic: { family: 'mci', glyph: 'traffic-light' },
  parking: { family: 'mci', glyph: 'parking' },
  fuel: { family: 'mci', glyph: 'gas-station' },
  charging: { family: 'mci', glyph: 'ev-station' },
  restaurant: { family: 'ion', glyph: 'restaurant' },
  hotel: { family: 'ion', glyph: 'bed' },
  attraction: { family: 'ion', glyph: 'camera' },

  // --- Connections ---
  people: { family: 'ion', glyph: 'people' },
  profile: { family: 'ion', glyph: 'person' },
  addPerson: { family: 'ion', glyph: 'person-add' },
  group: { family: 'mci', glyph: 'account-group' },
  family: { family: 'mci', glyph: 'account-child' },
  team: { family: 'mci', glyph: 'briefcase-account' },
  safeArrival: { family: 'mci', glyph: 'shield-check' },
  history: { family: 'ion', glyph: 'time' },
  permissions: { family: 'ion', glyph: 'lock-closed' },
  liveShare: { family: 'ion', glyph: 'share-social' },

  // --- Emergency ---
  sos: { family: 'mci', glyph: 'alarm-light' },
  ambulance: { family: 'mci', glyph: 'ambulance' },
  police: { family: 'mci', glyph: 'police-badge' },
  fire: { family: 'mci', glyph: 'fire' },
  roadside: { family: 'mci', glyph: 'tow-truck' },
  shareLocation: { family: 'mci', glyph: 'crosshairs-gps' },
  contacts: { family: 'mci', glyph: 'card-account-phone' },
  hospital: { family: 'mci', glyph: 'hospital-building' },
  clinic: { family: 'mci', glyph: 'medical-bag' },
  pharmacy: { family: 'mci', glyph: 'pill' },
  bloodBank: { family: 'mci', glyph: 'blood-bag' },
  call: { family: 'ion', glyph: 'call' },

  // --- ELLY AI ---
  elly: { family: 'ion', glyph: 'sparkles' },
  send: { family: 'ion', glyph: 'send' },
  suggestion: { family: 'mci', glyph: 'lightbulb-on' },
  leaveNow: { family: 'ion', glyph: 'car-sport' },
  planTrip: { family: 'mci', glyph: 'map-search' },
  bestTime: { family: 'ion', glyph: 'time' },
  bell: { family: 'ion', glyph: 'notifications' },
} as const satisfies Record<string, IconDef>;

export type IconName = keyof typeof ICONS;
