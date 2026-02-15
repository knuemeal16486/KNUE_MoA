import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/screens/home_page.dart';
import 'package:knue_moa/services/scraper_service.dart';  // ✅ 추가됨

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화
  await Hive.initFlutter();
  Hive.registerAdapter(NoticeAdapter()); // generated code
  await Hive.openBox<Notice>(KnueScraper.noticeBoxName);

  runApp(const ProviderScope(child: KnueMoaApp()));
}

class KnueMoaApp extends ConsumerWidget {
  const KnueMoaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KNUE MoA',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const HomePage(),
    );
  }
}