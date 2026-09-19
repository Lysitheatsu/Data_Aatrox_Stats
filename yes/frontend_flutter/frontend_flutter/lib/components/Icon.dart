import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/material.dart' as material show Icon;
import '../theme/icons.dart';
import '../theme/ThemeProvider.dart';

class Icon extends StatelessWidget {
  final IconName name;
  final double size;
  final Color? color;

  const Icon({
    super.key,
    required this.name,
    this.size = 22,
    this.color,
  });

  /**
   * Renders an ELLY icon by its registry name, dispatching to the correct
   * `flutter_vector_icons` family. See `lib/theme/icons.dart` for the mapping.
   */
  @override
  Widget build(BuildContext context) {
    final colors = useAppTheme(context).colors;
    final resolvedColor = color ?? colors.text;
    final def = ICONS[name]!;

    if (def.family == 'mci') {
      return material.Icon(
        def.glyph,
        size: size,
        color: resolvedColor,
      );
    }

    return material.Icon(
      def.glyph,
      size: size,
      color: resolvedColor,
    );
  }
}