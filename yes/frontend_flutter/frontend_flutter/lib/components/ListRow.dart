import 'package:flutter/material.dart';
import '../theme/index.dart';
import 'IconChip.dart';
import '../theme/icons.dart';

class ListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  /** Leading icon chip. */
  final IconName? icon;
  final Color? iconColor;
  /** Or a fully custom leading element (e.g. an Avatar). */
  final Widget? leading;
  /** Custom trailing element; defaults to a chevron when `chevron` is set. */
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onPress;
  final bool divider;

  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.onPress,
    this.divider = false,
  });

  /** Generic list row: leading media, title/subtitle, trailing action. */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = createStyles(colors);
    final resolvedIconColor = iconColor ?? colors.primary;
    return InkWell(
      onTap: onPress,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: styles.row.paddingVertical),
        decoration: divider ? styles.divider : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              IconChip(icon: icon!, color: resolvedIconColor),
            if (leading != null || icon != null) SizedBox(width: styles.row.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: styles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: styles.text.gap),
                    Text(
                      subtitle!,
                      style: styles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null || chevron) SizedBox(width: styles.row.gap),
            if (trailing != null)
              trailing!
            else if (chevron)
              Text('›', style: styles.chevron),
          ],
        ),
      ),
    );
  }
}

({
  ({
    double gap,
    double paddingVertical,
  }) row,
  BoxDecoration divider,
  ({double gap}) text,
  TextStyle title,
  TextStyle subtitle,
  TextStyle chevron,
}) createStyles(ThemeColors colors) {
  return (
    row: (
      gap: spacing.md,
      paddingVertical: spacing.sm,
    ),
    divider: BoxDecoration(
      border: Border(
        top: BorderSide(width: 1, color: colors.border),
      ),
    ),
    text: (gap: 2,),
    title: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w600, color: colors.text),
    subtitle: TextStyle(fontSize: fontSize.sm, color: colors.textMuted),
    chevron: TextStyle(fontSize: 22, color: colors.textFaint),
  );
}