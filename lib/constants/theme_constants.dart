import 'package:flutter/material.dart';

class AppTheme {
  static const Map<String, Map<String, dynamic>> themes = {
    'blue': {
      'name': 'KNUE Blue',
      'gradient': LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4338CA)]),
      'primary': Color(0xFF2563EB),
      'bgLight': Color(0xFFEFF6FF),
      'bannerBg': Color(0xFF1E1B4B),
      'ring': Color(0xFF3B82F6),
      'categoryColor': Color(0xFFDBEAFE),
      'categoryText': Color(0xFF1D4ED8),
    },
    'green': {
      'name': 'Fresh Green',
      'gradient': LinearGradient(colors: [Color(0xFF10B981), Color(0xFF0D9488)]),
      'primary': Color(0xFF10B981),
      'bgLight': Color(0xFFECFDF5),
      'bannerBg': Color(0xFF064E3B),
      'ring': Color(0xFF10B981),
      'categoryColor': Color(0xFFD1FAE5),
      'categoryText': Color(0xFF047857),
    },
    'orange': {
      'name': 'Sunset Orange',
      'gradient': LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
      'primary': Color(0xFFF97316),
      'bgLight': Color(0xFFFFF7ED),
      'bannerBg': Color(0xFF7C2D12),
      'ring': Color(0xFFF97316),
      'categoryColor': Color(0xFFFFEDD5),
      'categoryText': Color(0xFFC2410C),
    },
  };

  static Map<String, dynamic> getTheme(String key) => themes[key] ?? themes['blue']!;
}