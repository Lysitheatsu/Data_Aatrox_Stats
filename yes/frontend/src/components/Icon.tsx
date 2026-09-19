import React from 'react';
import Ionicons from '@expo/vector-icons/Ionicons';
import MaterialCommunityIcons from '@expo/vector-icons/MaterialCommunityIcons';
import { ICONS, IconName } from '@/theme/icons';
import { useAppTheme } from '@/theme/ThemeProvider';

interface Props {
  name: IconName;
  size?: number;
  color?: string;
}

/**
 * Renders an ELLY icon by its registry name, dispatching to the correct
 * `@expo/vector-icons` family. See `src/theme/icons.ts` for the mapping.
 */
export function Icon({
  name,
  size = 22,
  color,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const resolvedColor = color ?? colors.text;
  const def = ICONS[name];
  if (def.family === 'mci') {
    return (
      <MaterialCommunityIcons
        name={def.glyph as React.ComponentProps<typeof MaterialCommunityIcons>['name']}
        size={size}
        color={resolvedColor}
      />
    );
  }
  return (
    <Ionicons
      name={def.glyph as React.ComponentProps<typeof Ionicons>['name']}
      size={size}
      color={resolvedColor}
    />
  );
}
