import React from 'react';
import { ScrollView, StyleSheet, View, ViewStyle } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  children: React.ReactNode;
  /** Set false for screens that manage their own scrolling / fixed layout. */
  scroll?: boolean;
  background?: string;
  contentStyle?: ViewStyle;
}

/** Standard screen wrapper: safe-area top + optional vertical scroll. */
export function Screen({
  children,
  scroll = true,
  background,
  contentStyle,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const resolvedBackground = background ?? colors.background;
  const inner = <View style={[styles.body, contentStyle]}>{children}</View>;
  return (
    <SafeAreaView style={[styles.safe, { backgroundColor: resolvedBackground }]} edges={['top']}>
      {scroll ? (
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={styles.scroll}
        >
          {inner}
        </ScrollView>
      ) : (
        inner
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1 },
  scroll: { paddingBottom: spacing.xl },
  body: { paddingHorizontal: spacing.md, gap: spacing.md },
});
