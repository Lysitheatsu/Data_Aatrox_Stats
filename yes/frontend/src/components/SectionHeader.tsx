import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { fontSize, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  title: string;
  /** Optional right-aligned action (e.g. "View All"). */
  action?: string;
  onAction?: () => void;
  actionColor?: string;
}

export function SectionHeader({
  title,
  action,
  onAction,
  actionColor,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const resolvedActionColor = actionColor ?? colors.primary;
  return (
    <View style={styles.row}>
      <Text style={styles.title}>{title}</Text>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8}>
          <Text style={[styles.action, { color: resolvedActionColor }]}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    row: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: spacing.xs,
    },
    title: { fontSize: fontSize.lg, fontWeight: '700', color: colors.text },
    action: { fontSize: fontSize.sm, fontWeight: '600' },
  });
}
