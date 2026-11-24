import 'package:material_ui/material_ui.dart';

/// 8dp grid spacing, editorial border radii, touch targets, and breakpoints.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double radiusTag = 8;
  static const double radiusChip = 10;
  static const double radiusControl = 12;
  static const double radiusInput = 12;
  static const double radiusButton = 12;
  static const double radiusThumb = 12;
  static const double radiusBanner = 12;
  static const double radiusSurface = 16;
  static const double radiusCard = 18;
  static const double radiusHero = 20;
  static const double radiusDrawerSurface = 24;
  static const double radiusDrawerPill = 28;

  static const double minTouchTarget = 48;
  static const double secondaryButtonMinHeight = 52;
  static const double primaryButtonMinHeight = 56;
  static const double heroCtaMinHeight = 60;
  static const double selectionRowMinHeight = 60;
  static const double navBarHeight = 72;

  static const double drawerWidthTablet = 260;
  static const double drawerOpenScale = 0.86;

  static const double compactBreakpoint = 360;
  static const double largePhoneBreakpoint = 412;
  static const double tabletBreakpoint = 600;
  static const double largeTabletBreakpoint = 800;
  static const double largePhoneFormMaxWidth = 520;
  static const double tabletFormMaxWidth = 640;
  static const double largeTabletMaxWidth = 720;

  static bool isCompact(double width) => width < compactBreakpoint;

  static bool isTablet(double width) => width >= tabletBreakpoint;

  static double horizontalPadding(double width) {
    if (width >= largeTabletBreakpoint) {
      return xxxl;
    }
    if (width >= tabletBreakpoint) {
      return xxl;
    }
    if (width >= largePhoneBreakpoint) {
      return xl;
    }
    return lg;
  }

  static double maxContentWidth(double width) {
    if (width >= largeTabletBreakpoint) {
      return largeTabletMaxWidth;
    }
    if (width >= tabletBreakpoint) {
      return tabletFormMaxWidth;
    }
    if (width >= largePhoneBreakpoint) {
      return largePhoneFormMaxWidth;
    }
    return double.infinity;
  }

  static double adaptiveQrSize(double screenWidth, [double? screenHeight]) {
    final shortest = (screenHeight != null && screenHeight < screenWidth)
        ? screenHeight
        : screenWidth;
    final candidate = shortest * 0.62;
    return candidate.clamp(160.0, 256.0);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = horizontalPadding(width);
    return EdgeInsets.fromLTRB(horizontal, lg, horizontal, xxl);
  }
}
