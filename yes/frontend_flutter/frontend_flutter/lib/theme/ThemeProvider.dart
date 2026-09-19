import 'package:flutter/material.dart';
import 'index.dart';

class AppTheme {
  final AppColorScheme colorScheme;
  final bool isDark;
  final ThemeColors colors;

  const AppTheme({
    required this.colorScheme,
    required this.isDark,
    required this.colors,
  });
}

const defaultTheme = AppTheme(
  colorScheme: 'light',
  isDark: false,
  colors: lightColors,
);

class _ThemeContext extends InheritedWidget {
  final AppTheme value;

  const _ThemeContext({
    required this.value,
    required super.child,
  });

  static AppTheme? maybeOf(BuildContext context) {
    return context
      .dependOnInheritedWidgetOfExactType<_ThemeContext>()
      ?.value;
  }

  @override
  bool updateShouldNotify(_ThemeContext oldWidget) {
    return oldWidget.value.colorScheme != value.colorScheme;
  }
}

/** Follows the operating-system appearance and updates while the app is open. */
class ThemeProvider extends StatefulWidget {
  final Widget children;

  const ThemeProvider({
    super.key,
    required this.children,
  });

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<ThemeProvider>
    with WidgetsBindingObserver {
  Brightness systemScheme =
    WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      systemScheme =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColorScheme colorScheme =
      systemScheme == Brightness.dark ? 'dark' : 'light';

    final value = AppTheme(
      colorScheme: colorScheme,
      isDark: colorScheme == 'dark',
      colors: colorScheme == 'dark' ? darkColors : lightColors,
    );

    return _ThemeContext(
      value: value,
      child: Theme(
        data: ThemeData(
          brightness:
            value.isDark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: value.colors.background,
          extensions: [
            value.colors,
          ],
        ),
        child: widget.children,
      ),
    );
  }
}

AppTheme useAppTheme(BuildContext context) {
  return _ThemeContext.maybeOf(context) ?? defaultTheme;
}