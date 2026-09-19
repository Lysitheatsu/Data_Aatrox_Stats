import 'package:flutter/material.dart';
import '../theme/index.dart';

class SegmentedControl extends StatelessWidget {
  final List<String> segments;
  final String value;
  final ValueChanged<String>? onChange;
  final Color? color;

  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    this.onChange,
    this.color,
  });

  /** Pill segmented control (People / Groups / Requests). */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = createStyles(colors);
    final resolvedColor = color ?? colors.primary;
    return Container(
      padding: styles.track.padding,
      decoration: styles.track.decoration,
      child: Row(
        spacing: styles.track.gap,
        children: segments.map((seg) {
          final active = seg == value;
          return Expanded(
            child: InkWell(
              onTap: () => onChange?.call(seg),
              borderRadius: BorderRadius.circular(styles.seg.borderRadius),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: styles.seg.paddingVertical),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(styles.seg.borderRadius),
                  color: active ? colors.card : null,
                ),
                child: Text(
                  seg,
                  style: styles.label.copyWith(
                    color: active ? resolvedColor : colors.textMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

({
  ({
    EdgeInsets padding,
    double gap,
    BoxDecoration decoration,
  }) track,
  ({
    double paddingVertical,
    double borderRadius,
  }) seg,
  TextStyle label,
}) createStyles(ThemeColors colors) {
  return (
    track: (
      padding: EdgeInsets.all(spacing.xs),
      gap: spacing.xs,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
    ),
    seg: (
      paddingVertical: spacing.sm,
      borderRadius: radius.pill,
    ),
    label: TextStyle(fontSize: fontSize.sm),
  );
}