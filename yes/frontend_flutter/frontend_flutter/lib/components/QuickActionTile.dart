import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import 'icon.dart';
import '../theme/icons.dart';

/** Square tile for the Emergency "Quick Actions" grid. */
class QuickActionTile extends StatelessWidget {
  final IconName icon;
  final String label;
  final Color? color;
  final VoidCallback? onPress;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = createStyles(colors);
    final resolvedColor = color ?? colors.emergency;
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: InkWell(
          onTap: onPress,
          borderRadius: BorderRadius.circular(radius.md),
          child: Container(
            padding: styles.tile.padding,
            decoration: styles.tile.decoration,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(name: icon, size: 26, color: resolvedColor),
                SizedBox(height: styles.tile.gap),
                Text(
                  label,
                  style: styles.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({
  ({
    double gap,
    EdgeInsets padding,
    BoxDecoration decoration,
  }) tile,
  TextStyle label,
}) createStyles(ThemeColors colors) {
  return (
    tile: (
      gap: spacing.sm,
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius.md),
        color: colors.surface,
        border: Border.all(
          width: 1,
          color: colors.border,
        ),
      ),
    ),
    label: TextStyle(
      fontSize: fontSize.xs + 1,
      fontWeight: FontWeight.w600,
      color: colors.text,
    ),
  );
}