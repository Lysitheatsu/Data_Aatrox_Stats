import React from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { fontSize, spacing, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { Icon } from '@/components/Icon';
import { Avatar } from '@/components/Avatar';

interface Props {
  /** Rendered as the leading title; pass `logo` to style "ELLY" + "Maps". */
  title?: string;
  logo?: boolean;
  titleColor?: string;
  showMenu?: boolean;
  showBell?: boolean;
  bellDot?: boolean;
  showAvatar?: boolean;
  /** Custom leading icon (e.g. Emergency shield on the right in the ref). */
  rightIcon?: 'shield';
  rightIconColor?: string;
}

/** Top app bar shared by all screens. */
export function Header({
  title,
  logo = false,
  titleColor,
  showMenu = false,
  showBell = false,
  bellDot = false,
  showAvatar = false,
  rightIcon,
  rightIconColor,
}: Props): React.JSX.Element {
  const { colors } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors), [colors]);
  const resolvedTitleColor = titleColor ?? colors.text;
  const resolvedRightIconColor = rightIconColor ?? colors.primary;
  const [showLogoTooltip, setShowLogoTooltip] = React.useState(false);

  return (
    <View style={styles.bar}>
      <View style={styles.left}>
        {showMenu ? (
          <Pressable
            hitSlop={8}
            style={styles.menuBtn}
            onHoverIn={() => setShowLogoTooltip(true)}
            onHoverOut={() => setShowLogoTooltip(false)}
          >
            <Image source={require('../../assets/logo.png')} style={styles.menuLogo} />
          </Pressable>
        ) : null}
        {logo ? (
          <Pressable
            onHoverIn={() => setShowLogoTooltip(true)}
            onHoverOut={() => setShowLogoTooltip(false)}
          >
            <Text style={styles.logo}>
              <Text style={{ color: colors.text, fontWeight: '800' }}>ELLY </Text>
              <Text style={{ color: colors.textMuted, fontWeight: '600' }}>Maps</Text>
            </Text>
          </Pressable>
        ) : title ? (
          <Text style={[styles.title, { color: resolvedTitleColor }]}>{title}</Text>
        ) : null}

        {showLogoTooltip ? (
          <View style={styles.logoTooltip} pointerEvents="none">
            <Text style={styles.logoTooltipText}>
              one app, one power, total control, electra wireless
            </Text>
          </View>
        ) : null}
      </View>

      <View style={styles.right}>
        {showBell ? (
          <Pressable hitSlop={8} style={styles.iconBtn}>
            <Icon name="bell" size={22} color={colors.text} />
            {bellDot ? <View style={styles.bellDot} /> : null}
          </Pressable>
        ) : null}
        {rightIcon === 'shield' ? (
          <Pressable hitSlop={8} style={styles.iconBtn}>
            <Icon name="safeArrival" size={24} color={resolvedRightIconColor} />
          </Pressable>
        ) : null}
        {showAvatar ? <Avatar name="Shivam R" size={36} /> : null}
      </View>
    </View>
  );
}

function createStyles(colors: ThemeColors) {
  return StyleSheet.create({
    bar: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingVertical: spacing.sm,
    },
    left: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.sm,
      position: 'relative',
    },
    right: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    menuBtn: { paddingRight: spacing.xs },
    menuLogo: { width: 28, height: 28, resizeMode: 'contain' },
    logo: { fontSize: fontSize.xl },
    title: { fontSize: fontSize.xl, fontWeight: '800' },
    iconBtn: { position: 'relative' },
    bellDot: {
      position: 'absolute',
      top: -1,
      right: -1,
      width: 9,
      height: 9,
      borderRadius: 5,
      backgroundColor: colors.emergency,
      borderWidth: 1.5,
      borderColor: colors.background,
    },
    logoTooltip: {
      position: 'absolute',
      top: 38,
      left: 0,
      paddingVertical: spacing.xs,
      paddingHorizontal: spacing.sm,
      borderRadius: 6,
      backgroundColor: colors.card,
      borderWidth: 1,
      borderColor: colors.border,
      zIndex: 100,
    },
    logoTooltipText: {
      color: colors.text,
      fontSize: fontSize.xs,
      whiteSpace: 'nowrap',
    },
  });
}