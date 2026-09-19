import React from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { fontSize, radius, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';
import type { IconName } from '@/theme/icons';

interface Props {
  icon: IconName;
  label: string;
  color?: string;
  onPress?: () => void;
}

/** Square tile for the Emergency "Quick Actions" grid. */
export function QuickActionTile({
  icon,
  label,
  color,
  onPress,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const resolvedColor = color ?? colors.emergency;
  return (
    <Pressable onPress={onPress} style={styles.tile}>
      <Icon name={icon} size={26} color={resolvedColor} />
      <Text style={styles.label} numberOfLines={2}>
        {label}
      </Text>
    </Pressable>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    tile: {
      flex: 1,
      aspectRatio: 1,
      alignItems: 'center',
      justifyContent: 'center',
      gap: spacing.sm,
      padding: spacing.sm,
      borderRadius: radius.md,
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
    },
    label: {
      fontSize: fontSize.xs + 1,
      fontWeight: '600',
      color: colors.text,
      textAlign: 'center',
    },
  });
}
