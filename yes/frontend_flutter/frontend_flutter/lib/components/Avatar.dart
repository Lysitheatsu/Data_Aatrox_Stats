import 'package:flutter/material.dart' hide Icon;
import '../theme/index.dart';
import './Icon.dart';
import '../theme/ThemeProvider.dart';

// Deterministic pastel background per name so placeholders look intentional.
Color _bgFor(String name, List<Color> palette) {
  int h = 0;
  for (int i = 0; i < name.length; i += 1) h = (h + name.codeUnitAt(i)) % palette.length;
  return palette[h];
}

/** Default profile icon with optional sharing indicators. */
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  /** Draw a colored ring around the avatar (e.g. green for "Live"). */
  final Color? ring;
  /** Show a small status dot at the bottom-right. */
  final Color? dot;

  const Avatar({
    super.key,
    required this.name,
    this.size = 44,
    this.ring,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    final colors = useAppTheme(context).colors;
    final styles = _createStyles(colors);
    final palette = [
      colors.primary,
      colors.elly,
      colors.emergency,
      colors.success,
      colors.warning,
      colors.primaryDark,
    ];
    final base = _bgFor(name, palette);
    final dotSize = size * 0.28;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            alignment: styles['circle']['alignment'],
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size / 2),
              color: withAlpha(base, 0.18),
              border: ring != null ? Border.all(width: 2, color: ring!) : null,
            ),
            child: Icon(name: 'profile', size: size * 0.55, color: base),
          ),

          if (dot != null)
            Positioned(
              right: styles['dot']['right'],
              bottom: styles['dot']['bottom'],
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(dotSize / 2),
                  color: dot,
                  border: Border.all(
                    width: styles['dot']['borderWidth'],
                    color: styles['dot']['borderColor'],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _createStyles(ThemeColors colors) {
  return {
    'circle': { 'alignment': Alignment.center },
    'dot': {
      'right': 0.0,
      'bottom': 0.0,
      'borderWidth': 2.0,
      'borderColor': colors.background,
    },
  };
}