import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { getSectionColor } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';
import type { IconName } from '@/theme/icons';
import { MapScreen } from '@/screens/MapScreen';
import { ConnectionsScreen } from '@/screens/ConnectionsScreen';
import { EmergencyScreen } from '@/screens/EmergencyScreen';

const Tab = createBottomTabNavigator();

const TAB_ICON: Record<string, IconName> = {
  Map: 'tabMap',
  Connections: 'tabConnections',
  Emergency: 'tabEmergency',
};

/**
 * The current three-tab shell. Assistant features belong inside the screen
 * where they are useful, so ELLY AI no longer has a standalone tab.
 */
export function RootTabs(): React.JSX.Element {
  const { colors } = useAppTheme();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: getSectionColor(route.name, colors),
        tabBarInactiveTintColor: colors.textMuted,
        tabBarLabelStyle: { fontSize: 11 },
        tabBarStyle: {
          backgroundColor: colors.card,
          borderTopColor: colors.border,
        },
        sceneContainerStyle: { backgroundColor: colors.background },
        tabBarIcon: ({ color, size }) => (
          <Icon name={TAB_ICON[route.name]} size={size} color={color} />
        ),
      })}
    >
      <Tab.Screen name="Map" component={MapScreen} />
      <Tab.Screen name="Connections" component={ConnectionsScreen} />
      <Tab.Screen name="Emergency" component={EmergencyScreen} />
    </Tab.Navigator>
  );
}
