import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import 'icon.dart';
import 'avatar.dart';

class Header extends StatelessWidget {
  /** Rendered as the leading title; pass `logo` to style "ELLY" + "Maps". */
  final String? title;
  final bool logo;
  final Color? titleColor;
  final bool showMenu;
  final bool showBell;
  final bool bellDot;
  final bool showAvatar;
  /** Custom leading icon (e.g. Emergency shield on the right in the ref). */
  final String? rightIcon;
  final Color? rightIconColor;

  const Header({
    super.key,
    this.title,
    this.logo = false,
    this.titleColor,
    this.showMenu = false,
    this.showBell = false,
    this.bellDot = false,
    this.showAvatar = false,
    this.rightIcon,
    this.rightIconColor,
  });

  /** Top app bar shared by all screens. */
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final styles = createStyles(colors);
    final resolvedTitleColor = titleColor ?? colors.text;
    final resolvedRightIconColor = rightIconColor ?? colors.primary;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: styles.bar.paddingVertical),
      child: Row(
        crossAxisAlignment: styles.bar.crossAxisAlignment,
        mainAxisAlignment: styles.bar.mainAxisAlignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: styles.left.crossAxisAlignment,
            spacing: styles.left.gap,
            children: [
              if (showMenu)
                Tooltip(
                  message: 'one app, one power, total control, electra wireless',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Padding(
                    padding: EdgeInsets.only(right: styles.menuBtn.paddingRight),
                    child: Image.asset(
                      'assets/logo.png',
                      width: styles.menuLogo.width,
                      height: styles.menuLogo.height,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (logo)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'ELLY ', style: TextStyle(color: colors.text, fontWeight: FontWeight.w800)),
                      TextSpan(text: 'Maps', style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  style: styles.logo,
                )
              else if (title != null)
                Text(title!, style: styles.title.copyWith(color: resolvedTitleColor)),
            ],
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: styles.right.crossAxisAlignment,
            spacing: styles.right.gap,
            children: [
              if (showBell)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(name: 'bell', size: 22, color: colors.text),
                    if (bellDot)
                      Positioned(
                        top: styles.bellDot.top,
                        right: styles.bellDot.right,
                        child: Container(
                          width: styles.bellDot.width,
                          height: styles.bellDot.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(styles.bellDot.borderRadius),
                            color: styles.bellDot.backgroundColor,
                            border: Border.all(
                              width: styles.bellDot.borderWidth,
                              color: styles.bellDot.borderColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (rightIcon == 'shield')
                Icon(name: 'safeArrival', size: 24, color: resolvedRightIconColor),
              if (showAvatar) Avatar(name: 'Shivam R', size: 36),
            ],
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
    double paddingVertical,
  }) bar,
  ({
    CrossAxisAlignment crossAxisAlignment,
    double gap,
  }) left,
  ({
    CrossAxisAlignment crossAxisAlignment,
    double gap,
  }) right,
  ({double paddingRight}) menuBtn,
  ({
    double width,
    double height,
  }) menuLogo,
  TextStyle logo,
  TextStyle title,
  ({
    double top,
    double right,
    double width,
    double height,
    double borderRadius,
    Color backgroundColor,
    double borderWidth,
    Color borderColor,
  }) bellDot,
}) createStyles(ThemeColors colors) {
  return (
    bar: (
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      paddingVertical: spacing.sm,
    ),
    left: (crossAxisAlignment: CrossAxisAlignment.center, gap: spacing.sm),
    right: (crossAxisAlignment: CrossAxisAlignment.center, gap: spacing.md),
    menuBtn: (paddingRight: spacing.xs,),
    menuLogo: (width: 28, height: 28),
    logo: TextStyle(fontSize: fontSize.xl),
    title: TextStyle(fontSize: fontSize.xl, fontWeight: FontWeight.w800),
    bellDot: (
      top: -1,
      right: -1,
      width: 9,
      height: 9,
      borderRadius: 5,
      backgroundColor: colors.emergency,
      borderWidth: 1.5,
      borderColor: colors.background,
    ),
  );
}