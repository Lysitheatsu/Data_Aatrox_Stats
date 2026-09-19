import React from 'react';
import { StyleSheet, View } from 'react-native';
import { radius, withAlpha } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';
import type { IconName } from '@/theme/icons';

interface Props {
  icon: IconName;
  /** Accent used for the icon; the chip fill is a translucent tint of it. */
  color?: string;
  size?: number;
  /** Use a solid accent fill with a white icon (e.g. map markers). */
  solid?: boolean;
  rounded?: boolean;
}

/** The tinted rounded square that holds a single icon — used across the app. */
export function IconChip({
  icon,
  color,
  size = 40,
  solid = false,
  rounded = false,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const resolvedColor = color ?? colors.primary;
  return (
    <View
      style={[
        styles.chip,
        {
          width: size,
          height: size,
          borderRadius: rounded ? size / 2 : radius.md,
          backgroundColor: solid ? resolvedColor : withAlpha(resolvedColor, 0.14),
        },
      ]}
    >
      <Icon name={icon} size={size * 0.5} color={solid ? colors.onAccent : resolvedColor} />
    </View>
  );
}

const styles = StyleSheet.create({
  chip: { alignItems: 'center', justifyContent: 'center' },
});
