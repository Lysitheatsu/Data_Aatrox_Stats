import 'package:flutter/material.dart' hide Card;
import '../theme/index.dart';

class Card extends StatelessWidget {
  final Widget children;
  final BoxDecoration? style;
  final bool padded;

  const Card({
    super.key,
    required this.children,
    this.style,
    this.padded = true,
  });

  /** White elevated container used for every grouped section. */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styles = createStyles(colors, isDark);
    return Container(
      decoration: style ?? styles.card,
      padding: padded ? styles.padded : null,
      child: children,
    );
  }
}

({BoxDecoration card, EdgeInsets padded}) createStyles(ThemeColors colors, bool isDark) {
  return (
    card: BoxDecoration(
      color: colors.card,
      borderRadius: BorderRadius.circular(radius.lg),
      border: Border.all(
        width: 1,
        color: colors.border,
      ),
      boxShadow: cardShadow(colors, isDark),
    ),
    padded: EdgeInsets.all(spacing.md),
  );
}