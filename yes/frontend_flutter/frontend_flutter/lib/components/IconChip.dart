import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import 'icon.dart';
import '../theme/icons.dart';

/** The tinted rounded square that holds a single icon — used across the app. */
class IconChip extends StatelessWidget {
  final IconName icon;
  /** Accent used for the icon; the chip fill is a translucent tint of it. */
  final Color? color;
  final double size;
  /** Use a solid accent fill with a white icon (e.g. map markers). */
  final bool solid;
  final bool rounded;

  const IconChip({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.solid = false,
    this.rounded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final resolvedColor = color ?? colors.primary;
    return Container(
      width: size,
      height: size,
      alignment: styles.chip,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rounded ? size / 2 : radius.md),
        color: solid ? resolvedColor : withAlpha(resolvedColor, 0.14),
      ),
      child: Icon(name: icon, size: size * 0.5, color: solid ? colors.onAccent : resolvedColor),
    );
  }
}

const styles = (
  chip: Alignment.center,
);