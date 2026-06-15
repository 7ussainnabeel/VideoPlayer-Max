import 'package:flutter/material.dart';

class AppStyles {
  // Theme Colors
  static const Color primaryRed = Color(0xFFFF5252); // Modern vibrant coral red
  static const Color headerText = Colors.white;
  static const Color scaffoldBackground = Color(0xFF0F172A); // Dark slate background fallback
  static const Color listBackground = Colors.transparent;
  
  // Navigation Bar Colors
  static const Color bottomNavBg = Colors.transparent; // Managed via Glass Navigation dock
  static const Color bottomNavSelected = Color(0xFFFF5252);
  static const Color bottomNavUnselected = Colors.white60;

  // Text Colors
  static const Color textDark = Colors.white;
  static const Color textGray = Colors.white60;
  static const Color textBlack = Color(0xFF1C1C1E);

  // Border Colors
  static const Color dividerColor = Colors.white10;

  // Dynamic getters to support both light and dark themes with liquid glass aesthetics
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF0F172A) // Sleek slate-900 for high readability on light backdrop
        : Colors.white;
  }

  static Color getSubtextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF475569) // Slate-600
        : Colors.white70;
  }

  static Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF334155) // Slate-700
        : Colors.white70;
  }

  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.1)
        : Colors.white10;
  }

  static Color getChevronColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF94A3B8) // Slate-400
        : Colors.white54;
  }

  // Text Styles
  static const TextStyle headerTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: headerText,
  );

  static const TextStyle headerActionStyle = TextStyle(
    fontSize: 16,
    color: headerText,
  );

  static const TextStyle mediaTitleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle mediaDurationStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  static const TextStyle importOptionStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: textDark,
  );
}

