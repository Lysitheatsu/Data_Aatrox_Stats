import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import '../theme/ThemeProvider.dart';
import '../components/Icon.dart';
import '../theme/icons.dart';
import '../api/client.dart';
import '../screens/MapScreen.dart';
import '../screens/ConnectionsScreen.dart';
import '../screens/EmergencyScreen.dart';

const Map<String, IconName> TAB_ICON = {
  'Map': 'tabMap',
  'Connections': 'tabConnections',
  'Emergency': 'tabEmergency',
};

/**
 * The current three-tab shell. Assistant features belong inside the screen
 * where they are useful, so ELLY AI no longer has a standalone tab.
 */
class RootTabs extends StatefulWidget {
  const RootTabs({super.key});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int selectedIndex = 0;
  GeoLocation? mapFocusLocation;

  final tabs = [
    'Map',
    'Connections',
    'Emergency',
  ];

  void selectTab(String route) {
    final index = tabs.indexOf(route);
    if (index == -1) return;
    setState(() {
      selectedIndex = index;
    });
  }

  void openMapLocation(GeoLocation location) {
    setState(() {
      mapFocusLocation = location;
      selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = useAppTheme(context).colors;
    final screens = [
      MapScreen(
        onNavigateTab: selectTab,
        focusLocation: mapFocusLocation,
      ),
      const ConnectionsScreen(),
      EmergencyScreen(onOpenMapLocation: openMapLocation),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(
            top: BorderSide(
              color: colors.border,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          selectedItemColor: getSectionColor(tabs[selectedIndex], colors),
          unselectedItemColor: colors.textMuted,
          selectedLabelStyle: const TextStyle(fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          backgroundColor: colors.card,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: tabs.map((route) => BottomNavigationBarItem(
            icon: Icon(
              name: TAB_ICON[route]!,
              size: 24,
              color: route == tabs[selectedIndex]
                ? getSectionColor(route, colors)
                : colors.textMuted,
            ),
            label: route,
          )).toList(),
        ),
      ),
    );
  }
}