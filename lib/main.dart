import 'package:flutter/material.dart';
import 'package:knue_moa/screens/home_page.dart';

void main() => runApp(const KnueMoaApp());

class KnueMoaApp extends StatefulWidget {
  const KnueMoaApp({super.key});
  @override
  State<KnueMoaApp> createState() => _KnueMoaAppState();
}

class _KnueMoaAppState extends State<KnueMoaApp> {
  String _themeKey = 'blue';

  // React THEMES 정의와 동일한 구성
  final Map<String, Map<String, dynamic>> _themes = {
    'blue': {
      'name': 'KNUE Blue',
      'gradient': const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4338CA)]),
      'primary': const Color(0xFF2563EB),
      'bgLight': const Color(0xFFEFF6FF),
      'bannerBg': const Color(0xFF1E1B4B),
      'ring': const Color(0xFF3B82F6),
      'categoryColor': const Color(0xFFDBEAFE),
      'categoryText': const Color(0xFF1D4ED8),
    },
    'green': {
      'name': 'Fresh Green',
      'gradient': const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF0D9488)]),
      'primary': const Color(0xFF10B981),
      'bgLight': const Color(0xFFECFDF5),
      'bannerBg': const Color(0xFF064E3B),
      'ring': const Color(0xFF10B981),
      'categoryColor': const Color(0xFFD1FAE5),
      'categoryText': const Color(0xFF047857),
    },
    'orange': {
      'name': 'Sunset Orange',
      'gradient': const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
      'primary': const Color(0xFFF97316),
      'bgLight': const Color(0xFFFFF7ED),
      'bannerBg': const Color(0xFF7C2D12),
      'ring': const Color(0xFFF97316),
      'categoryColor': const Color(0xFFFFEDD5),
      'categoryText': const Color(0xFFC2410C),
    },
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Pretendard'),
      home: HomePage(
        currentTheme: _themes[_themeKey]!,
        themeKey: _themeKey,
        onThemeChange: (key) => setState(() => _themeKey = key),
      ),
    );
  }
}