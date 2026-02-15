import 'package:flutter/material.dart';
import 'screens/home_page.dart'; // lib/screens/home_page.dart 경로에 파일이 있어야 합니다.

void main() {
  runApp(const KnueMoaApp());
}

class KnueMoaApp extends StatelessWidget {
  const KnueMoaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KNUE MoA', // 앱 이름
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        fontFamily: 'Pretendard',
      ),
      home: const HomePage(), // 앱 실행 시 보여줄 첫 화면
      debugShowCheckedModeBanner: false, // 오른쪽 상단 'Debug' 띠 제거
    );
  }
}