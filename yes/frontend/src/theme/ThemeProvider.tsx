import React from 'react';
import { useColorScheme } from 'react-native';
import {
  darkColors,
  lightColors,
  type AppColorScheme,
  type ThemeColors,
} from '@/theme';

interface AppTheme {
  colorScheme: AppColorScheme;
  isDark: boolean;
  colors: ThemeColors;
}

const defaultTheme: AppTheme = {
  colorScheme: 'light',
  isDark: false,
  colors: lightColors,
};

const ThemeContext = React.createContext<AppTheme>(defaultTheme);

/** Follows the operating-system appearance and updates while the app is open. */
export function ThemeProvider({ children }: { children: React.ReactNode }): React.JSX.Element {
  const systemScheme = useColorScheme();
  const colorScheme: AppColorScheme = systemScheme === 'dark' ? 'dark' : 'light';

  const value = React.useMemo<AppTheme>(
    () => ({
      colorScheme,
      isDark: colorScheme === 'dark',
      colors: colorScheme === 'dark' ? darkColors : lightColors,
    }),
    [colorScheme],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useAppTheme(): AppTheme {
  return React.useContext(ThemeContext);
}
