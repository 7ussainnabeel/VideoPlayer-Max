import 'package:flutter/material.dart';

class AppStyles {
  // Theme Colors
  static const Color primaryRed = Color(0xFFE53935); // The red header bar color
  static const Color headerText = Colors.white;
  static const Color scaffoldBackground = Color(0xFFF2F6F9); // Light grayish/blue background in list/imports
  static const Color listBackground = Colors.white;
  
  // Navigation Bar Colors
  static const Color bottomNavBg = Color(0xFF121212); // Dark navigation bar
  static const Color bottomNavSelected = Color(0xFFE53935);
  static const Color bottomNavUnselected = Color(0xFF8E8E93);

  // Text Colors
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color textGray = Color(0xFF636366);

  // Border Colors
  static const Color dividerColor = Color(0xFFE5E5EA);

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
