import React from 'react';
import { StyleSheet, TextInput, View } from 'react-native';
import { cardShadow, fontSize, radius, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';

interface Props {
  placeholder: string;
  showMic?: boolean;
  /** Leave these out and it just sits there looking like a search bar. */
  value?: string;
  onChangeText?: (text: string) => void;
  onSubmit?: () => void;
}

/**
 * The search box at the top of the Map screen.
 *
 * Used to be a plain bit of text that looked like a search bar. Now it's a
 * real input so you can actually type a place name into it.
 */
export function SearchBar({
  placeholder,
  showMic = true,
  value,
  onChangeText,
  onSubmit,
}: Props): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors, isDark), [colors, isDark]);
  return (
    <View style={styles.bar}>
      <Icon name="search" size={20} color={colors.textMuted} />
      <TextInput
        style={styles.input}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        selectionColor={colors.primary}
        value={value}
        onChangeText={onChangeText}
        onSubmitEditing={onSubmit}
        returnKeyType="search"
        editable={onChangeText !== undefined}
      />
      {showMic ? <Icon name="voice" size={20} color={colors.primary} /> : null}
    </View>
  );
}

function createStyles(colors: ThemeColors, isDark: boolean) {
  return StyleSheet.create({
    bar: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.sm,
      backgroundColor: colors.card,
      borderRadius: radius.pill,
      borderWidth: 1,
      borderColor: colors.border,
      paddingVertical: spacing.sm + 2,
      paddingHorizontal: spacing.md,
      ...cardShadow(colors, isDark),
    },
    input: {
      flex: 1,
      fontSize: fontSize.md,
      color: colors.text,
      // stops the browser drawing its own outline on web
      outlineStyle: 'none',
    } as never,
  });
}
