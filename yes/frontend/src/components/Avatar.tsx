import React from 'react';
import { StyleSheet, View } from 'react-native';
import { withAlpha, type ThemeColors } from '@/theme';
import { Icon } from './Icon';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  name: string;
  size?: number;
  /** Draw a colored ring around the avatar (e.g. green for "Live"). */
  ring?: string;
  /** Show a small status dot at the bottom-right. */
  dot?: string;
}

// Deterministic pastel background per name so placeholders look intentional.
function bgFor(name: string, palette: string[]): string {
  let h = 0;
  for (let i = 0; i < name.length; i += 1) h = (h + name.charCodeAt(i)) % palette.length;
  return palette[h];
}

/** Default profile icon with optional sharing indicators. */
export function Avatar({ name, size = 44, ring, dot }: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const palette = [
    colors.primary,
    colors.elly,
    colors.emergency,
    colors.success,
    colors.warning,
    colors.primaryDark,
  ];
  const base = bgFor(name, palette);
  const dotSize = size * 0.28;
  return (
    <View style={{ width: size, height: size }}>
      <View
        style={[
          styles.circle,
          {
            width: size,
            height: size,
            borderRadius: size / 2,
            backgroundColor: withAlpha(base, 0.18),
            borderWidth: ring ? 2 : 0,
            borderColor: ring,
          },
        ]}
      >
        <Icon name="profile" size={size * 0.55} color={base} />
      </View>
      {dot ? (
        <View
          style={[
            styles.dot,
            {
              width: dotSize,
              height: dotSize,
              borderRadius: dotSize / 2,
              backgroundColor: dot,
            },
          ]}
        />
      ) : null}
    </View>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    circle: { alignItems: 'center', justifyContent: 'center' },
    dot: {
      position: 'absolute',
      right: 0,
      bottom: 0,
      borderWidth: 2,
      borderColor: colors.background,
    },
  });
}
