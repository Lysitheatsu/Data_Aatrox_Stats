import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/ThemeProvider.dart';
import 'data/AppDataProvider.dart';
import 'navigation/RootTabs.dart';
import 'screens/MapScreen.dart';
import 'screens/ConnectionsScreen.dart';
import 'screens/EmergencyScreen.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThemeProvider(
      children: AppDataProvider(
        children: ThemedApp(),
      ),
    );
  }
}

class ThemedApp extends StatelessWidget {
  const ThemedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = useAppTheme(context);
    final colors = theme.colors;
    final isDark = theme.isDark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: colors.background,
        statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
          isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'ELLY Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness:
          isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: colors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness:
            isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: colors.primary,
          surface: colors.card,
          error: colors.emergency,
          onSurface: colors.text,
        ),
        extensions: [
          colors,
        ],
      ),
      home: const RootTabs(),
      routes: {
        'Map': (context) => const MapScreen(),
        'Connections': (context) => const ConnectionsScreen(),
        'Emergency': (context) => const EmergencyScreen(),
      },
    );
  }
}