/**
 * ELLY Maps design tokens.
 *
 * COLOR EDITING GUIDE
 * -------------------
 * The two objects below are the only place where light/dark mode colours
 * should be changed. Both palettes are sampled from the approved mockups in
 * reference/; keeping every semantic colour here makes any future retune a
 * small, reviewable change.
 */
import 'package:flutter/material.dart';

class ThemeColors extends ThemeExtension<ThemeColors> {
  // Brand / section accents
  final Color primary;
  final Color primaryDark;
  final Color elly;
  final Color emergency;
  final Color emergencyDark;

  // Status
  final Color success;
  final Color live;
  final Color warning;

  // Text
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color onAccent;

  // Surfaces
  final Color background;
  final Color card;
  final Color surface;
  final Color surfaceAlt;
  final Color mapBackdrop;
  final Color mapPark;
  final Color border;
  final Color borderStrong;

  // Miscellaneous
  final Color shadow;
  final Color overlay;
  final Color scrim;
  final Color avatarFallback;

  const ThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.elly,
    required this.emergency,
    required this.emergencyDark,

    required this.success,
    required this.live,
    required this.warning,

    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.onAccent,

    required this.background,
    required this.card,
    required this.surface,
    required this.surfaceAlt,
    required this.mapBackdrop,
    required this.mapPark,
    required this.border,
    required this.borderStrong,

    required this.shadow,
    required this.overlay,
    required this.scrim,
    required this.avatarFallback,
  });

  @override
  ThemeColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? elly,
    Color? emergency,
    Color? emergencyDark,

    Color? success,
    Color? live,
    Color? warning,

    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? onAccent,

    Color? background,
    Color? card,
    Color? surface,
    Color? surfaceAlt,
    Color? mapBackdrop,
    Color? mapPark,
    Color? border,
    Color? borderStrong,

    Color? shadow,
    Color? overlay,
    Color? scrim,
    Color? avatarFallback,
  }) {
    return ThemeColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      elly: elly ?? this.elly,
      emergency: emergency ?? this.emergency,
      emergencyDark: emergencyDark ?? this.emergencyDark,

      success: success ?? this.success,
      live: live ?? this.live,
      warning: warning ?? this.warning,

      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      onAccent: onAccent ?? this.onAccent,

      background: background ?? this.background,
      card: card ?? this.card,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      mapBackdrop: mapBackdrop ?? this.mapBackdrop,
      mapPark: mapPark ?? this.mapPark,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,

      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      scrim: scrim ?? this.scrim,
      avatarFallback: avatarFallback ?? this.avatarFallback,
    );
  }

  @override
  ThemeColors lerp(ThemeColors? other, double t) {
    if (other == null) return this;

    return ThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      elly: Color.lerp(elly, other.elly, t)!,
      emergency: Color.lerp(emergency, other.emergency, t)!,
      emergencyDark: Color.lerp(emergencyDark, other.emergencyDark, t)!,

      success: Color.lerp(success, other.success, t)!,
      live: Color.lerp(live, other.live, t)!,
      warning: Color.lerp(warning, other.warning, t)!,

      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,

      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      mapBackdrop: Color.lerp(mapBackdrop, other.mapBackdrop, t)!,
      mapPark: Color.lerp(mapPark, other.mapPark, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,

      shadow: Color.lerp(shadow, other.shadow, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      avatarFallback: Color.lerp(avatarFallback, other.avatarFallback, t)!,
    );
  }
}

/** Light palette taken from reference/Elly Maps Overview Design.jpeg. */
const lightColors = ThemeColors(
  primary: Color(0xFF2563EB),
  primaryDark: Color(0xFF1D4ED8),
  elly: Color(0xFF7C3AED),
  emergency: Color(0xFFEF4444),
  emergencyDark: Color(0xFFDC2626),

  success: Color(0xFF16A34A),
  live: Color(0xFF22C55E),
  warning: Color(0xFFF59E0B),

  text: Color(0xFF0F172A),
  textMuted: Color(0xFF64748B),
  textFaint: Color(0xFF94A3B8),
  onAccent: Color(0xFFFFFFFF),

  background: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  surface: Color(0xFFF8FAFC),
  surfaceAlt: Color(0xFFF1F5F9),
  mapBackdrop: Color(0xFFEAF0F6),
  mapPark: Color(0xFFDCEBD8),
  border: Color(0xFFE2E8F0),
  borderStrong: Color(0xFFCBD5E1),

  shadow: Color(0xFF0F172A),
  overlay: Color.fromRGBO(15, 23, 42, 0.04),
  scrim: Color.fromRGBO(0, 0, 0, 0.40),
  avatarFallback: Color(0xFFCBD5E1),
);

/**
 * Dark palette sampled from reference/Elly Dark and Light Mode Design.png (the
 * ELLY assistant mockup) and the dark dashboard reference. The scheme is a deep
 * purple-black canvas with violet accents rather than a neutral slate, so every
 * surface carries a violet cast and the greys are tinted to match.
 */
const darkColors = ThemeColors(
  // Violet accent family: the mockup's send button and the dashboard's active
  // nav item. `primary` is used as a solid fill under white `onAccent` text so
  // it stays dark enough to keep that legible; `elly` is only ever a tint or
  // text on a dark surface, so it can be the brighter brand lavender.
  primary: Color(0xFF8B5CF6),
  primaryDark: Color(0xFF7526E4),
  elly: Color(0xFFB794FF),
  emergency: Color(0xFFF87171),
  emergencyDark: Color(0xFFEF4444),

  success: Color(0xFF4ADE80),
  live: Color(0xFF4ADE80),
  warning: Color(0xFFFBBF24),

  text: Color(0xFFF6F2FF),
  textMuted: Color(0xFFB7ADD4),
  textFaint: Color(0xFF8378A8),
  onAccent: Color(0xFFFFFFFF),

  // Surfaces step up from the near-black canvas through the mockup's input bar
  // to its icon chips — each one a lighter step of the same purple.
  background: Color(0xFF09021C),
  card: Color(0xFF150C2B),
  surface: Color(0xFF1B1036),
  surfaceAlt: Color(0xFF241741),
  mapBackdrop: Color(0xFF0F0629),
  mapPark: Color(0xFF153125),
  border: Color(0xFF2E1F4D),
  borderStrong: Color(0xFF3E2C63),

  shadow: Color(0xFF000000),
  overlay: Color.fromRGBO(183, 148, 255, 0.06),
  scrim: Color.fromRGBO(8, 2, 24, 0.66),
  avatarFallback: Color(0xFF3E2C63),
);

typedef AppColorScheme = String;

/** Section accent by app area, resolved against the active palette. */
Color getSectionColor(String name, ThemeColors colors) {
  if (name == 'Emergency') return colors.emergency;
  if (name == 'Elly AI') return colors.elly;
  return colors.primary;
}

/** Translucent tints of an accent (e.g. icon chip backgrounds). */
Color withAlpha(Color color, double alpha) {
  final resolvedAlpha = (alpha * 255).round().clamp(0, 255);
  return color.withAlpha(resolvedAlpha);
}

const spacing = (
  xs: 4.0,
  sm: 8.0,
  md: 16.0,
  lg: 24.0,
  xl: 32.0,
);

const radius = (
  sm: 8.0,
  md: 12.0,
  lg: 20.0,
  pill: 999.0,
);

const fontSize = (
  xs: 11.0,
  sm: 13.0,
  md: 15.0,
  lg: 17.0,
  xl: 22.0,
  xxl: 28.0,
);

/** Cross-platform card elevation, adjusted for the active colour scheme. */
List<BoxShadow> cardShadow(ThemeColors colors, bool isDark) {
  return [
    BoxShadow(
      color: withAlpha(colors.shadow, isDark ? 0.24 : 0.06),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];
}