import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import 'icon.dart';

class SearchBar extends StatefulWidget {
  final String placeholder;
  final bool showMic;
  /** Leave these out and it just sits there looking like a search bar. */
  final String? value;
  final ValueChanged<String>? onChangeText;
  final VoidCallback? onSubmit;

  const SearchBar({
    super.key,
    required this.placeholder,
    this.showMic = true,
    this.value,
    this.onChangeText,
    this.onSubmit,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

/**
 * The search box at the top of the Map screen.
 *
 * Used to be a plain bit of text that looked like a search bar. Now it's a
 * real input so you can actually type a place name into it.
 */
class _SearchBarState extends State<SearchBar> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != controller.text) {
      controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ThemeColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styles = createStyles(colors, isDark);
    return Container(
      padding: styles.bar.padding,
      decoration: styles.bar.decoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(name: 'search', size: 20, color: colors.textMuted),
          SizedBox(width: styles.bar.gap),
          Expanded(
            child: TextField(
              controller: controller,
              style: styles.input,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: styles.input.copyWith(color: colors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              cursorColor: colors.primary,
              onChanged: widget.onChangeText,
              onSubmitted: (_) => widget.onSubmit?.call(),
              textInputAction: TextInputAction.search,
              readOnly: widget.onChangeText == null,
            ),
          ),
          if (widget.showMic) ...[
            SizedBox(width: styles.bar.gap),
            Icon(name: 'voice', size: 20, color: colors.primary),
          ],
        ],
      ),
    );
  }
}

({
  ({
    double gap,
    EdgeInsets padding,
    BoxDecoration decoration,
  }) bar,
  TextStyle input,
}) createStyles(ThemeColors colors, bool isDark) {
  return (
    bar: (
      gap: spacing.sm,
      padding: EdgeInsets.symmetric(
        vertical: spacing.sm + 2,
        horizontal: spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(
          width: 1,
          color: colors.border,
        ),
        boxShadow: cardShadow(colors, isDark),
      ),
    ),
    input: TextStyle(
      fontSize: fontSize.md,
      color: colors.text,
      // stops the browser drawing its own outline on web
    ),
  );
}