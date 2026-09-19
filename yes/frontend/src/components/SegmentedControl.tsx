import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { fontSize, radius, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  segments: string[];
  value: string;
  onChange?: (segment: string) => void;
  color?: string;
}

/** Pill segmented control (People / Groups / Requests). */
export function SegmentedControl({
  segments,
  value,
  onChange,
  color,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const resolvedColor = color ?? colors.primary;
  return (
    <View style={styles.track}>
      {segments.map((seg) => {
        const active = seg === value;
        return (
          <Pressable
            key={seg}
            onPress={() => onChange?.(seg)}
            style={[styles.seg, active && { backgroundColor: colors.card }]}
          >
            <Text
              style={[
                styles.label,
                { color: active ? resolvedColor : colors.textMuted, fontWeight: active ? '700' : '600' },
              ]}
            >
              {seg}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    track: {
      flexDirection: 'row',
      backgroundColor: colors.surfaceAlt,
      borderRadius: radius.pill,
      padding: spacing.xs,
      gap: spacing.xs,
    },
    seg: {
      flex: 1,
      alignItems: 'center',
      paddingVertical: spacing.sm,
      borderRadius: radius.pill,
    },
    label: { fontSize: fontSize.sm },
  });
}
