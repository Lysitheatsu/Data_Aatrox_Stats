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

export interface ThemeColors {
  // Brand / section accents
  primary: string;
  primaryDark: string;
  elly: string;
  emergency: string;
  emergencyDark: string;

  // Status
  success: string;
  live: string;
  warning: string;

  // Text
  text: string;
  textMuted: string;
  textFaint: string;
  onAccent: string;

  // Surfaces
  background: string;
  card: string;
  surface: string;
  surfaceAlt: string;
  mapBackdrop: string;
  mapPark: string;
  border: string;
  borderStrong: string;

  // Miscellaneous
  shadow: string;
  overlay: string;
  scrim: string;
  avatarFallback: string;
}

/** Light palette taken from reference/Elly Maps Overview Design.jpeg. */
export const lightColors: ThemeColors = {
  primary: '#2563EB',
  primaryDark: '#1D4ED8',
  elly: '#7C3AED',
  emergency: '#EF4444',
  emergencyDark: '#DC2626',

  success: '#16A34A',
  live: '#22C55E',
  warning: '#F59E0B',

  text: '#0F172A',
  textMuted: '#64748B',
  textFaint: '#94A3B8',
  onAccent: '#FFFFFF',

  background: '#FFFFFF',
  card: '#FFFFFF',
  surface: '#F8FAFC',
  surfaceAlt: '#F1F5F9',
  mapBackdrop: '#EAF0F6',
  mapPark: '#DCEBD8',
  border: '#E2E8F0',
  borderStrong: '#CBD5E1',

  shadow: '#0F172A',
  overlay: 'rgba(15, 23, 42, 0.04)',
  scrim: 'rgba(0, 0, 0, 0.40)',
  avatarFallback: '#CBD5E1',
};

/**
 * Dark palette sampled from reference/Elly Dark and Light Mode Design.png (the
 * ELLY assistant mockup) and the dark dashboard reference. The scheme is a deep
 * purple-black canvas with violet accents rather than a neutral slate, so every
 * surface carries a violet cast and the greys are tinted to match.
 */
export const darkColors: ThemeColors = {
  // Violet accent family: the mockup's send button and the dashboard's active
  // nav item. `primary` is used as a solid fill under white `onAccent` text so
  // it stays dark enough to keep that legible; `elly` is only ever a tint or
  // text on a dark surface, so it can be the brighter brand lavender.
  primary: '#8B5CF6',
  primaryDark: '#7526E4',
  elly: '#B794FF',
  emergency: '#F87171',
  emergencyDark: '#EF4444',

  success: '#4ADE80',
  live: '#4ADE80',
  warning: '#FBBF24',

  text: '#F6F2FF',
  textMuted: '#B7ADD4',
  textFaint: '#8378A8',
  onAccent: '#FFFFFF',

  // Surfaces step up from the near-black canvas through the mockup's input bar
  // to its icon chips — each one a lighter step of the same purple.
  background: '#09021C',
  card: '#150C2B',
  surface: '#1B1036',
  surfaceAlt: '#241741',
  mapBackdrop: '#0F0629',
  mapPark: '#153125',
  border: '#2E1F4D',
  borderStrong: '#3E2C63',

  shadow: '#000000',
  overlay: 'rgba(183, 148, 255, 0.06)',
  scrim: 'rgba(8, 2, 24, 0.66)',
  avatarFallback: '#3E2C63',
};

export type AppColorScheme = 'light' | 'dark';

/** Section accent by app area, resolved against the active palette. */
export function getSectionColor(name: string, colors: ThemeColors): string {
  if (name === 'Emergency') return colors.emergency;
  if (name === 'Elly AI') return colors.elly;
  return colors.primary;
}

/** Translucent tints of an accent (e.g. icon chip backgrounds). */
export const withAlpha = (hex: string, alpha: number): string => {
  const a = Math.round(alpha * 255).toString(16).padStart(2, '0');
  return `${hex}${a}`;
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 20,
  pill: 999,
} as const;

export const fontSize = {
  xs: 11,
  sm: 13,
  md: 15,
  lg: 17,
  xl: 22,
  xxl: 28,
} as const;

/** Cross-platform card elevation, adjusted for the active colour scheme. */
export function cardShadow(colors: ThemeColors, isDark: boolean) {
  return {
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: isDark ? 0.24 : 0.06,
    shadowRadius: 12,
    elevation: isDark ? 2 : 3,
  } as const;
}
