import 'package:flutter/material.dart';
import '../theme/index.dart';

class Tag extends StatelessWidget {
  final String label;
  final Color? color;
  /** Show a leading filled dot (e.g. the "Live" indicator). */
  final bool dot;

  const Tag({
    super.key,
    required this.label,
    this.color,
    this.dot = true,
  });

  /** Compact status tag, e.g. green "Live". */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final resolvedColor = color ?? colors.live;
    return Container(
      padding: styles.tag.padding,
      decoration: BoxDecoration(
        color: withAlpha(resolvedColor, 0.14),
        borderRadius: BorderRadius.circular(styles.tag.borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dot)
            Container(
              width: styles.dot.width,
              height: styles.dot.height,
              decoration: BoxDecoration(
                color: resolvedColor,
                borderRadius: BorderRadius.circular(styles.dot.borderRadius),
              ),
            ),
          if (dot) SizedBox(width: styles.tag.gap),
          Text(label, style: styles.label.copyWith(color: resolvedColor)),
        ],
      ),
    );
  }
}

final styles = (
  tag: (
    gap: spacing.xs,
    padding: EdgeInsets.symmetric(
      vertical: 2,
      horizontal: spacing.sm,
    ),
    borderRadius: radius.pill,
  ),
  dot: (
    width: 6.0,
    height: 6.0,
    borderRadius: 3.0,
  ),
  label: TextStyle(fontSize: fontSize.xs, fontWeight: FontWeight.w700),
);