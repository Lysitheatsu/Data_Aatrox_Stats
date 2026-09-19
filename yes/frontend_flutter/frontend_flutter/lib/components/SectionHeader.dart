import 'package:flutter/material.dart';
import '../theme/index.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  /** Optional right-aligned action (e.g. "View All"). */
  final String? action;
  final VoidCallback? onAction;
  final Color? actionColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = createStyles(colors);
    final resolvedActionColor = actionColor ?? colors.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: styles.row.marginBottom),
      child: Row(
        crossAxisAlignment: styles.row.crossAxisAlignment,
        mainAxisAlignment: styles.row.mainAxisAlignment,
        children: [
          Text(title, style: styles.title),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: styles.action.copyWith(color: resolvedActionColor)),
            ),
        ],
      ),
    );
  }
}

({
  ({
    CrossAxisAlignment crossAxisAlignment,
    MainAxisAlignment mainAxisAlignment,
    double marginBottom,
  }) row,
  TextStyle title,
  TextStyle action,
}) createStyles(ThemeColors colors) {
  return (
    row: (
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      marginBottom: spacing.xs,
    ),
    title: TextStyle(fontSize: fontSize.lg, fontWeight: FontWeight.w700, color: colors.text),
    action: TextStyle(fontSize: fontSize.sm, fontWeight: FontWeight.w600),
  );
}