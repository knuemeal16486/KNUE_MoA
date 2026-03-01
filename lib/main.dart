import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/models/personal_schedule_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:knue_moa/screens/home_page.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:knue_moa/models/application_model.dart';
import 'package:knue_moa/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // home_widget은 Android / iOS 전용 (Windows에서는 스킵)
  if (Platform.isAndroid || Platform.isIOS) {
    await HomeWidget.setAppGroupId('group.com.knue.knuemoa');
  }

  await Hive.initFlutter();
  Hive.registerAdapter(NoticeAdapter());
  Hive.registerAdapter(ApplicationFormAdapter());
  Hive.registerAdapter(PersonalScheduleAdapter());
  await Hive.openBox<Notice>(KnueScraper.noticeBoxName);
  await Hive.openBox<PersonalSchedule>(PersonalScheduleNotifier.boxName);

  // Riverpod: ProviderScope를 루트로 두어 전역 상태·의존성 주입 제공
  runApp(const ProviderScope(child: KnueMoaApp()));
}

class KnueMoaApp extends ConsumerWidget {
  const KnueMoaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 테마만 변경될 때만 리빌드되도록 watch
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
