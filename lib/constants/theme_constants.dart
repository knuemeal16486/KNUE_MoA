import 'package:flutter/material.dart';

class AppTheme {
  // KNUE Mate 20색상 팔레트
  static const List<Color> palette = [
    Color(0xFF2563EB), Color(0xFFEF5350), Color(0xFFEC407A), Color(0xFFAB47BC),
    Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFF039BE5), Color(0xFF00ACC1),
    Color(0xFF00897B), Color(0xFF43A047), Color(0xFF7CB342), Color(0xFFC0CA33),
    Color(0xFFFDD835), Color(0xFFFFB300), Color(0xFFFB8C00), Color(0xFFF4511E),
    Color(0xFF6D4C41), Color(0xFF757575), Color(0xFF546E7A), Color(0xFF000000),
  ];

  static ThemeData getTheme(Color primaryColor, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      cardColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      dividerColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
    );
  }
}