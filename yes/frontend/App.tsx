import React from 'react';
import { StatusBar } from 'react-native';
import { NavigationContainer, type Theme as NavigationTheme } from '@react-navigation/native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import * as SystemUI from 'expo-system-ui';
import { RootTabs } from '@/navigation/RootTabs';
import { ThemeProvider, useAppTheme } from '@/theme/ThemeProvider';
import { AppDataProvider } from '@/data/AppDataProvider';

export default function App(): React.JSX.Element {
  return (
    <SafeAreaProvider>
      <ThemeProvider>
        <AppDataProvider>
          <ThemedApp />
        </AppDataProvider>
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

function ThemedApp(): React.JSX.Element {
  const { colors, isDark } = useAppTheme();

  React.useEffect(() => {
    void SystemUI.setBackgroundColorAsync(colors.background);
  }, [colors.background]);

  const navigationTheme = React.useMemo<NavigationTheme>(
    () => ({
      dark: isDark,
      colors: {
        primary: colors.primary,
        background: colors.background,
        card: colors.card,
        text: colors.text,
        border: colors.border,
        notification: colors.emergency,
      },
    }),
    [colors, isDark],
  );

  return (
    <NavigationContainer theme={navigationTheme}>
      <StatusBar
        barStyle={isDark ? 'light-content' : 'dark-content'}
        backgroundColor={colors.background}
      />
      <RootTabs />
    </NavigationContainer>
  );
}
