import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:knue_moa/screens/home_page.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:knue_moa/models/application_model.dart';
import 'package:knue_moa/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // iOS 홈 위젯 연동을 위한 App Group ID 설정
  await HomeWidget.setAppGroupId('group.com.example.knue_moa');

  await Hive.initFlutter();
  Hive.registerAdapter(NoticeAdapter());
  Hive.registerAdapter(ApplicationFormAdapter());
  await Hive.openBox<Notice>(KnueScraper.noticeBoxName);

  runApp(const ProviderScope(child: KnueMoaApp()));
}

class KnueMoaApp extends ConsumerWidget {
  const KnueMoaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(themeColorProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KNUE MoA',
      theme: AppTheme.getTheme(primaryColor, Brightness.light),
      darkTheme: AppTheme.getTheme(primaryColor, Brightness.dark),
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}
