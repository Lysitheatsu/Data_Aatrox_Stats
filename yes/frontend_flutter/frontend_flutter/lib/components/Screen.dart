import 'package:flutter/material.dart';
import '../theme/index.dart';
import '../theme/ThemeProvider.dart';

class Screen extends StatelessWidget {
  final Widget children;
  /** Set false for screens that manage their own scrolling / fixed layout. */
  final bool scroll;
  final Color? background;
  final EdgeInsetsGeometry? contentStyle;

  const Screen({
    super.key,
    required this.children,
    this.scroll = true,
    this.background,
    this.contentStyle,
  });

  /** Standard screen wrapper: safe-area top + optional vertical scroll. */
  @override
  Widget build(BuildContext context) {
    final colors = useAppTheme(context).colors;
    final resolvedBackground = background ?? colors.background;
    final inner = Padding(
      padding: contentStyle ?? _styles.body.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _styles.body.gap,
        children: [children],
      ),
    );
    return ColoredBox(
      color: resolvedBackground,
      child: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: scroll
          ? SingleChildScrollView(
              padding: _styles.scroll,
              child: inner,
            )
          : inner,
      ),
    );
  }
}

final _styles = (
  safe: (
    flex: 1,
  ),
  scroll: EdgeInsets.only(bottom: spacing.xl),
  body: (
    padding: EdgeInsets.symmetric(horizontal: spacing.md),
    gap: spacing.md,
  ),
);