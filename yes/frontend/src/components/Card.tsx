import React from 'react';
import { StyleSheet, View, ViewStyle } from 'react-native';
import { cardShadow, radius, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  children: React.ReactNode;
  style?: ViewStyle;
  padded?: boolean;
}

/** White elevated container used for every grouped section. */
export function Card({ children, style, padded = true }: Props): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors, isDark), [colors, isDark]);
  return (
    <View style={[styles.card, padded && styles.padded, style]}>{children}</View>
  );
}

function createStyles(colors: ThemeColors, isDark: boolean) {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.card,
      borderRadius: radius.lg,
      borderWidth: 1,
      borderColor: colors.border,
      ...cardShadow(colors, isDark),
    },
    padded: { padding: spacing.md },
  });
}
