import type { NearbyCategory } from '@/api/client';
import type { IconName } from '@/theme/icons';

/**
 * The eight things you can look for near you.
 *
 * Each one gets its own colour so a screen full of pins is still readable.
 * The keys match what the backend expects.
 */

export interface CategoryInfo {
  key: NearbyCategory;
  label: string;
  icon: IconName;
  colour: string;
}

export const NEARBY_CATEGORIES: CategoryInfo[] = [
  { key: 'restaurants', label: 'Food', icon: 'restaurant', colour: '#F97316' },
  { key: 'hospitals', label: 'Hospitals', icon: 'hospital', colour: '#EF4444' },
  { key: 'pharmacies', label: 'Pharmacies', icon: 'pharmacy', colour: '#10B981' },
  { key: 'petrol_stations', label: 'Petrol', icon: 'fuel', colour: '#EAB308' },
  { key: 'parking', label: 'Parking', icon: 'parking', colour: '#3B82F6' },
  { key: 'charging_stations', label: 'Charging', icon: 'charging', colour: '#22C55E' },
  { key: 'hotels', label: 'Hotels', icon: 'hotel', colour: '#8B5CF6' },
  { key: 'attractions', label: 'Attractions', icon: 'attraction', colour: '#EC4899' },
];

export function categoryInfo(key: NearbyCategory): CategoryInfo {
  return NEARBY_CATEGORIES.find((c) => c.key === key) ?? NEARBY_CATEGORIES[0];
}
