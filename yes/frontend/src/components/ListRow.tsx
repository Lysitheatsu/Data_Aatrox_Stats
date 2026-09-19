import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { fontSize, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { IconChip } from '@/components/IconChip';
import type { IconName } from '@/theme/icons';

interface Props {
  title: string;
  subtitle?: string;
  /** Leading icon chip. */
  icon?: IconName;
  iconColor?: string;
  /** Or a fully custom leading element (e.g. an Avatar). */
  leading?: React.ReactNode;
  /** Custom trailing element; defaults to a chevron when `chevron` is set. */
  trailing?: React.ReactNode;
  chevron?: boolean;
  onPress?: () => void;
  divider?: boolean;
}

/** Generic list row: leading media, title/subtitle, trailing action. */
export function ListRow({
  title,
  subtitle,
  icon,
  iconColor,
  leading,
  trailing,
  chevron = false,
  onPress,
  divider = false,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const resolvedIconColor = iconColor ?? colors.primary;
  return (
    <Pressable
      onPress={onPress}
      style={[styles.row, divider && styles.divider]}
    >
      {leading ?? (icon ? <IconChip icon={icon} color={resolvedIconColor} /> : null)}
      <View style={styles.text}>
        <Text style={styles.title} numberOfLines={1}>
          {title}
        </Text>
        {subtitle ? (
          <Text style={styles.subtitle} numberOfLines={1}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {trailing ?? (chevron ? <Text style={styles.chevron}>›</Text> : null)}
    </Pressable>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    row: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.md,
      paddingVertical: spacing.sm,
    },
    divider: { borderTopWidth: 1, borderTopColor: colors.border },
    text: { flex: 1, gap: 2 },
    title: { fontSize: fontSize.md, fontWeight: '600', color: colors.text },
    subtitle: { fontSize: fontSize.sm, color: colors.textMuted },
    chevron: { fontSize: 22, color: colors.textFaint, marginLeft: spacing.xs },
  });
}
