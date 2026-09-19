import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import 'icon.dart';
import '../theme/icons.dart';

typedef Variant = String;

class Button extends StatelessWidget {
  final String label;
  final VoidCallback? onPress;
  final Variant variant;
  final Color? color;
  final IconName? icon;
  final String size;
  final BoxDecoration? style;

  const Button({
    super.key,
    required this.label,
    this.onPress,
    this.variant = 'solid',
    this.color,
    this.icon,
    this.size = 'md',
    this.style,
  });

  /** App button. Buttons are visual-only for now (no wired handlers required). */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final resolvedColor = color ?? colors.primary;
    final solid = variant == 'solid';
    final soft = variant == 'soft';
    final fg = solid ? colors.onAccent : resolvedColor;
    final pad = size == 'sm'
      ? EdgeInsets.symmetric(vertical: spacing.xs + 2, horizontal: spacing.md)
      : EdgeInsets.symmetric(vertical: spacing.sm + 2, horizontal: spacing.lg);
    return InkWell(
      onTap: onPress,
      borderRadius: BorderRadius.circular(radius.pill),
      child: Container(
        padding: pad,
        decoration: style ?? BoxDecoration(
          color: solid ? resolvedColor : soft ? withAlpha(resolvedColor, 0.12) : Colors.transparent,
          border: variant == 'outline' ? Border.all(width: 1, color: resolvedColor) : null,
          borderRadius: BorderRadius.circular(radius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(name: icon!, size: size == 'sm' ? 15 : 18, color: fg),
            if (icon != null) SizedBox(width: spacing.xs + 2),
            Text(
              label,
              style: styles.label.copyWith(color: fg, fontSize: size == 'sm' ? fontSize.sm : fontSize.md),
            ),
          ],
        ),
      ),
    );
  }
}

class _Styles {
  final TextStyle label;

  const _Styles({
    required this.label,
  });
}

const styles = _Styles(
  label: TextStyle(fontWeight: FontWeight.w600),
);