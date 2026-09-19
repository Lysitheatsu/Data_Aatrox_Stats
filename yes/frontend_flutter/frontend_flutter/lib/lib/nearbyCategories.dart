import 'package:flutter/material.dart';
import '../api/client.dart';
import '../theme/icons.dart';

/**
 * The eight things you can look for near you.
 *
 * Each one gets its own colour so a screen full of pins is still readable.
 * The keys match what the backend expects.
 */

class CategoryInfo {
  final NearbyCategory key;
  final String label;
  final IconName icon;
  final Color colour;

  const CategoryInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.colour,
  });
}

final List<CategoryInfo> NEARBY_CATEGORIES = [
  CategoryInfo(key: 'restaurants', label: 'Food', icon: 'restaurant', colour: Color(0xFFF97316)),
  CategoryInfo(key: 'hospitals', label: 'Hospitals', icon: 'hospital', colour: Color(0xFFEF4444)),
  CategoryInfo(key: 'pharmacies', label: 'Pharmacies', icon: 'pharmacy', colour: Color(0xFF10B981)),
  CategoryInfo(key: 'petrol_stations', label: 'Petrol', icon: 'fuel', colour: Color(0xFFEAB308)),
  CategoryInfo(key: 'parking', label: 'Parking', icon: 'parking', colour: Color(0xFF3B82F6)),
  CategoryInfo(key: 'charging_stations', label: 'Charging', icon: 'charging', colour: Color(0xFF22C55E)),
  CategoryInfo(key: 'hotels', label: 'Hotels', icon: 'hotel', colour: Color(0xFF8B5CF6)),
  CategoryInfo(key: 'attractions', label: 'Attractions', icon: 'attraction', colour: Color(0xFFEC4899)),
];

CategoryInfo categoryInfo(NearbyCategory key) {
  return NEARBY_CATEGORIES.firstWhere(
    (c) => c.key == key,
    orElse: () => NEARBY_CATEGORIES[0],
  );
}