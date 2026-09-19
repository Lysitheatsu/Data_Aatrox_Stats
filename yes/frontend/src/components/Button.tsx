import React from 'react';
import { Pressable, StyleSheet, Text, ViewStyle } from 'react-native';
import { fontSize, radius, spacing, withAlpha } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';
import type { IconName } from '@/theme/icons';

type Variant = 'solid' | 'soft' | 'outline';

interface Props {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  color?: string;
  icon?: IconName;
  size?: 'sm' | 'md';
  style?: ViewStyle;
}

/** App button. Buttons are visual-only for now (no wired handlers required). */
export function Button({
  label,
  onPress,
  variant = 'solid',
  color,
  icon,
  size = 'md',
  style,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const resolvedColor = color ?? colors.primary;
  const solid = variant === 'solid';
  const soft = variant === 'soft';
  const fg = solid ? colors.onAccent : resolvedColor;
  const pad = size === 'sm'
    ? { paddingVertical: spacing.xs + 2, paddingHorizontal: spacing.md }
    : { paddingVertical: spacing.sm + 2, paddingHorizontal: spacing.lg };
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.base,
        pad,
        {
          backgroundColor: solid ? resolvedColor : soft ? withAlpha(resolvedColor, 0.12) : 'transparent',
          borderWidth: variant === 'outline' ? 1 : 0,
          borderColor: resolvedColor,
        },
        style,
      ]}
    >
      {icon ? <Icon name={icon} size={size === 'sm' ? 15 : 18} color={fg} /> : null}
      <Text style={[styles.label, { color: fg, fontSize: size === 'sm' ? fontSize.sm : fontSize.md }]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs + 2,
    borderRadius: radius.pill,
  },
  label: { fontWeight: '600' },
});
