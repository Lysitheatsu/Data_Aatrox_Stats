import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { fontSize, radius, spacing, withAlpha } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  label: string;
  color?: string;
  /** Show a leading filled dot (e.g. the "Live" indicator). */
  dot?: boolean;
}

/** Compact status tag, e.g. green "Live". */
export function Tag({ label, color, dot = true }: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const resolvedColor = color ?? colors.live;
  return (
    <View style={[styles.tag, { backgroundColor: withAlpha(resolvedColor, 0.14) }]}>
      {dot ? <View style={[styles.dot, { backgroundColor: resolvedColor }]} /> : null}
      <Text style={[styles.label, { color: resolvedColor }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  tag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    alignSelf: 'flex-start',
    paddingVertical: 2,
    paddingHorizontal: spacing.sm,
    borderRadius: radius.pill,
  },
  dot: { width: 6, height: 6, borderRadius: 3 },
  label: { fontSize: fontSize.xs, fontWeight: '700' },
});
