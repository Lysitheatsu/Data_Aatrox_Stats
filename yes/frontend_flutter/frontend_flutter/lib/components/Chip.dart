import 'package:flutter/material.dart' hide Chip, Icon;
import '../theme/index.dart';
import 'icon.dart';
import '../theme/icons.dart';

class Chip extends StatelessWidget {
  final String label;
  final IconName? icon;
  final Color? iconColor;
  final VoidCallback? onPress;

  const Chip({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.onPress,
  });

  /** Small pill used for the "Popular" quick prompts. */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = createStyles(colors);
    final resolvedIconColor = iconColor ?? colors.primary;
    return InkWell(
      onTap: onPress,
      borderRadius: BorderRadius.circular(radius.pill),
      child: Container(
        padding: styles.chip.padding,
        decoration: styles.chip.decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) Icon(name: icon!, size: 15, color: resolvedIconColor),
            if (icon != null) SizedBox(width: styles.chip.gap),
            Text(label, style: styles.label),
          ],
        ),
      ),
    );
  }
}

ChipStyles createStyles(ThemeColors colors) {
  return ChipStyles(
    chip: ChipStyle(
      gap: spacing.xs + 2,
      padding: EdgeInsets.symmetric(
        vertical: spacing.sm,
        horizontal: spacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius.pill),
        color: colors.card,
        border: Border.all(
          width: 1,
          color: colors.border,
        ),
      ),
    ),
    label: TextStyle(fontSize: fontSize.sm, fontWeight: FontWeight.w600, color: colors.text),
  );
}

class ChipStyle {
  final double gap;
  final EdgeInsets padding;
  final BoxDecoration decoration;

  const ChipStyle({
    required this.gap,
    required this.padding,
    required this.decoration,
  });
}

class ChipStyles {
  final ChipStyle chip;
  final TextStyle label;

  const ChipStyles({
    required this.chip,
    required this.label,
  });
}