import React from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { fontSize, radius, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';
import type { IconName } from '@/theme/icons';

interface Props {
  label: string;
  icon?: IconName;
  iconColor?: string;
  onPress?: () => void;
}

/** Small pill used for the "Popular" quick prompts. */
export function Chip({
  label,
  icon,
  iconColor,
  onPress,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const resolvedIconColor = iconColor ?? colors.primary;
  return (
    <Pressable onPress={onPress} style={styles.chip}>
      {icon ? <Icon name={icon} size={15} color={resolvedIconColor} /> : null}
      <Text style={styles.label}>{label}</Text>
    </Pressable>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    chip: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.xs + 2,
      paddingVertical: spacing.sm,
      paddingHorizontal: spacing.md,
      borderRadius: radius.pill,
      backgroundColor: colors.card,
      borderWidth: 1,
      borderColor: colors.border,
    },
    label: { fontSize: fontSize.sm, fontWeight: '600', color: colors.text },
  });
}
