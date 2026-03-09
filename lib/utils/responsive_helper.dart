import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 900;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  /// Returns responsive font size based on screen width
  static double fontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) {
      // Very small devices
      return baseFontSize * 0.85;
    } else if (width < 400) {
      // Small devices
      return baseFontSize * 0.92;
    } else if (width >= 600) {
      // Tablets and larger
      return baseFontSize * 1.1;
    }
    return baseFontSize;
  }

  /// Returns responsive padding based on screen width
  static EdgeInsets padding(BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    final width = MediaQuery.of(context).size.width;
    final multiplier = width < 360 ? 0.7 : (width < 400 ? 0.85 : 1.0);

    if (all != null) {
      return EdgeInsets.all(all * multiplier);
    }
    return EdgeInsets.symmetric(
      horizontal: (horizontal ?? 0) * multiplier,
      vertical: (vertical ?? 0) * multiplier,
    );
  }

  /// Returns responsive spacing
  static double spacing(BuildContext context, double baseSpacing) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) {
      return baseSpacing * 0.7;
    } else if (width < 400) {
      return baseSpacing * 0.85;
    }
    return baseSpacing;
  }

  /// Returns responsive icon size
  static double iconSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) {
      return baseSize * 0.8;
    } else if (width < 400) {
      return baseSize * 0.9;
    }
    return baseSize;
  }

  /// Returns responsive height
  static double height(BuildContext context, double baseHeight) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) {
      return baseHeight * 0.85;
    } else if (width < 400) {
      return baseHeight * 0.92;
    }
    return baseHeight;
  }

  /// Returns responsive border radius
  static double borderRadius(BuildContext context, double baseRadius) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) {
      return baseRadius * 0.8;
    }
    return baseRadius;
  }

  /// Safe area padding with responsive adjustments
  static EdgeInsets safeAreaPadding(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final width = MediaQuery.of(context).size.width;
    final multiplier = width < 360 ? 0.8 : 1.0;
    
    return EdgeInsets.only(
      top: padding.top * multiplier,
      bottom: padding.bottom * multiplier,
      left: padding.left * multiplier,
      right: padding.right * multiplier,
    );
  }

  /// Returns cross axis count for grids
  static int gridCrossAxisCount(BuildContext context, {int mobileCount = 2, int tabletCount = 3, int desktopCount = 4}) {
    if (isDesktop(context)) return desktopCount;
    if (isTablet(context)) return tabletCount;
    return mobileCount;
  }

  /// Screen width breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}
